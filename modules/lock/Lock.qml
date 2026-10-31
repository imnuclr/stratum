import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.services
import qs.theme

/*
 * Locking the session.
 *
 * Three ways in, all the same lock: the IPC call, the session menu, and logind's
 * own Lock signal — which is what `loginctl lock-session` and any idle daemon
 * send, so those work without being taught about this shell. There is no IPC to
 * unlock: the way out is the password, or `loginctl unlock-session`, which only
 * the session's own user can send.
 *
 * `preview` shows the same screen in an ordinary window, without taking the
 * session lock, for looking at it and for trying the password path safely.
 */
Scope {
    id: root

    property bool preview: false

    /*
     * If the shell ever goes down while the screen is locked, Hyprland keeps the
     * session locked and shows its "lock screen crashed" screen. With this on, a
     * shell started again (stratum start, from a TTY) takes the lock back over
     * and shows the password box, instead of the only way out being a reboot.
     */
    Component.onCompleted: {
        if (Hypr.lua)
            Hypr.configure("{ misc = { allow_session_lock_restore = true } }");
        else
            Quickshell.execDetached(["hyprctl", "keyword", "misc:allow_session_lock_restore", "1"]);
    }
    // What the compositor has confirmed, not what was last asked for: `locked`
    // is the request and was seen reading true after the session had been released.
    readonly property bool locked: session.secure

    // logind's path for this session, so another session's lock is not ours. The
    // bus escapes a leading digit, which is how session 3 becomes `_33`.
    readonly property string sessionPath: {
        const id = Quickshell.env("XDG_SESSION_ID") ?? "";
        if (id.length === 0)
            return "";
        const first = id.charAt(0);
        const escaped = /[0-9]/.test(first) ? "_" + first.charCodeAt(0).toString(16) + id.slice(1) : id;
        return `/org/freedesktop/login1/session/${escaped}`;
    }

    function lock() {
        console.info(`[lock] asked to lock (secure=${session.secure})`);
        if (session.secure)
            return;
        Shell.close();
        credentials.reset();
        session.locked = true;
    }

    /*
     * About to sleep — the lid closing, or anything else that suspends. The
     * screen is locked first so the machine wakes up locked, which is what
     * closing a laptop is usually taken to mean. `lock.onSleep: false` leaves
     * it unlocked.
     */
    function sleeping() {
        if (!Config.get("lock.onSleep", true))
            return;
        console.info("[lock] sleeping, locking first");
        root.lock();
    }

    /*
     * Awake again. Services that are polled on a timer have been frozen for as
     * long as the machine slept, so each is nudged — a clock an hour behind and
     * a battery reading from yesterday are what the first seconds after waking
     * otherwise look like.
     */
    function woke() {
        console.info("[lock] awake");
        Time.now = new Date();
        Netstat.reset();
    }

    function release() {
        console.info("[lock] releasing");
        session.locked = false;
        root.preview = false;
        credentials.reset();
    }

    LockAuth {
        id: credentials

        // Let the screen finish fading before the lock drops, rather than cutting
        // to the desktop mid-fade.
        onUnlocked: letGo.start()
    }

    Timer {
        id: letGo

        // The ring filling, then the screen drawing in (LockScreen's depart).
        interval: Math.max(60, Theme.speed * 680)
        onTriggered: root.release()
    }

    WlSessionLock {
        id: session

        // Each step, in the log, so a lock that fails says how far it got.
        onLockedChanged: console.info(`[lock] locked=${locked}`)
        onSecureChanged: console.info(`[lock] compositor confirms secure=${secure}`)

        LockSurface {
            auth: credentials
        }
    }

    Loader {
        active: root.preview

        sourceComponent: PanelWindow {
            screen: Quickshell.screens.find(s => s.name === Shell.fallbackScreen) ?? Quickshell.screens[0]
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "stratum-lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            color: "black"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            LockScreen {
                anchors.fill: parent
                auth: credentials
                onEscaped: root.preview = false
            }
        }
    }

    Process {
        id: logind

        running: true
        command: [
            "dbus-monitor", "--system",
            "type='signal',interface='org.freedesktop.login1.Session',member='Lock'",
            "type='signal',interface='org.freedesktop.login1.Session',member='Unlock'",
            // Closing the lid suspends the machine, and logind says so here
            // rather than asking for a lock; without this the laptop woke up
            // unlocked.
            "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'"
        ]

        /*
         * PrepareForSleep carries its true or false on the line after the
         * signal, so the signal is remembered until that line arrives.
         */
        property bool sleepNext: false

        stdout: SplitParser {
            onRead: line => {
                if (logind.sleepNext) {
                    const b = line.match(/boolean (true|false)/);
                    if (b) {
                        logind.sleepNext = false;
                        if (b[1] === "true")
                            root.sleeping();
                        else
                            root.woke();
                        return;
                    }
                }
                if (/member=PrepareForSleep\b/.test(line)) {
                    logind.sleepNext = true;
                    return;
                }
                const m = line.match(/path=(\S+?);.*member=(Lock|Unlock)\b/);
                if (!m)
                    return;
                if (root.sessionPath.length > 0 && m[1] !== root.sessionPath)
                    return;
                if (m[2] === "Lock")
                    root.lock();
                else
                    root.release();
            }
        }

        // Without this a dropped monitor would leave `loginctl lock-session`
        // doing nothing until the shell was restarted.
        onRunningChanged: if (!running) revive.start()
    }

    Timer {
        id: revive

        interval: 2000
        onTriggered: logind.running = true
    }

    // SUPER + L, via a bind that points here. Nothing on this side knows which key.
    GlobalShortcut {
        appid: "stratum"
        name: "lock"
        onPressed: root.lock()
    }

    IpcHandler {
        target: "lock"

        function lock(): void {
            root.lock();
        }

        function preview(): void {
            root.preview = true;
        }

        function endPreview(): void {
            root.preview = false;
        }

        function isLocked(): bool {
            return root.locked;
        }
    }
}
