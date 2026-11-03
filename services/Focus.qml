pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

/*
 * Focus modes: what is allowed to interrupt, by what you are doing.
 *
 * One mode at a time, or none. Each silences notification toasts except from
 * the apps it lets through, and some change something else while they are on —
 * Sleep warms the screen, Gaming turns on game mode — and put it back after.
 * Nothing is thrown away: silenced notifications are still listed, as do not
 * disturb always did. A critical one, a battery about to run out, always gets
 * through.
 *
 * The mode and when it ends are kept in shell.json, so a restart or a reboot
 * keeps you in it. Settings → Notifications → Focus edits the rest: which
 * apps each mode lets through (`focus.allow.<mode>`, matched against the
 * sender's name or desktop id), which modes the control centre offers, what
 * Sleep and Gaming change, when "until morning" ends, and whether critical
 * notifications break through.
 */
Singleton {
    id: root

    readonly property var modes: [
        { id: "dnd", name: "Do Not Disturb", icon: "bell-off", allow: [] },
        { id: "sleep", name: "Sleep", icon: "moon", allow: [] },
        { id: "work", name: "Work", icon: "briefcase",
            allow: ["slack", "teams", "outlook", "thunderbird", "zoom"] },
        { id: "personal", name: "Personal", icon: "person",
            allow: ["discord", "vesktop", "equibop", "legcord", "whatsapp", "signal", "telegram"] },
        { id: "gaming", name: "Gaming", icon: "gamepad",
            allow: ["discord", "vesktop", "equibop", "legcord"] }
    ]

    readonly property string mode: Config.get("focus.mode", "")
    // Epoch ms when it ends by itself, or 0 for when it is turned off.
    readonly property real until: Config.get("focus.until", 0)

    readonly property bool on: root.current !== null
    readonly property var current: root.modes.find(m => m.id === root.mode) ?? null
    // The last mode used, for the pill's tap to bring back.
    readonly property string last: Config.get("focus.last", "dnd")

    // The modes the control centre offers; the one that is on always shows.
    readonly property var hidden: Config.get("focus.hidden", []) ?? []
    readonly property var shown: root.modes.filter(m => !root.hidden.includes(m.id) || m.id === root.mode)

    function setShown(id, value) {
        Config.set("focus.hidden", value ? root.hidden.filter(x => x !== id) : root.hidden.concat([id]));
    }

    readonly property bool criticalThrough: Config.get("focus.critical", true)
    readonly property int morningHour: Config.get("focus.morning", 7)
    readonly property bool sleepWarms: Config.get("focus.sleepNight", true)
    readonly property bool gamingGameMode: Config.get("focus.gamingGameMode", true)

    function defaults(id) {
        return root.modes.find(x => x.id === id)?.allow ?? [];
    }

    function setAllowed(id, text) {
        const list = String(text).split(",").map(x => x.trim()).filter(x => x.length > 0);
        Config.set(`focus.allow.${id}`, list);
    }

    function allowed(id) {
        const m = root.modes.find(x => x.id === id);
        return Config.get(`focus.allow.${id}`, m?.allow ?? []) ?? [];
    }

    // Nothing gets through, so the toasts need not be on screen at all.
    readonly property bool silencesAll: root.on && root.allowed(root.mode).length === 0

    function silences(notification) {
        if (!root.on || !notification)
            return false;
        if (root.criticalThrough && notification.urgency === NotificationUrgency.Critical)
            return false;
        const sender = `${notification.appName ?? ""} ${notification.desktopEntry ?? ""}`.toLowerCase();
        return !root.allowed(root.mode).some(a => sender.includes(String(a).toLowerCase()));
    }

    /*
     * Turns a mode on. `length` is "off" for until it is turned off, "hour" for
     * an hour, "morning" for tomorrow at `focus.morning` o'clock.
     */
    function set(id, length) {
        if (!root.modes.some(m => m.id === id))
            return;
        root.leave();
        let end = 0;
        if (length === "hour") {
            end = Date.now() + 3600000;
        } else if (length === "morning") {
            const d = new Date();
            d.setDate(d.getDate() + 1);
            d.setHours(root.morningHour, 0, 0, 0);
            end = d.getTime();
        }
        Config.set("focus.mode", id);
        Config.set("focus.until", end);
        Config.set("focus.last", id);
        root.enter(id);
    }

    function stop() {
        if (!root.on)
            return;
        root.leave();
        Config.set("focus.mode", "");
        Config.set("focus.until", 0);
    }

    function toggle(id) {
        if (root.mode === (id ?? root.last))
            root.stop();
        else if (id === undefined && root.on)
            root.stop();
        else
            root.set(id ?? root.last, "off");
    }

    // What changed on entering, to put back on leaving, and only that: a night
    // light that was already on before Sleep stays on after it.
    property bool startedNight: false
    property bool startedGame: false

    function enter(id) {
        if (id === "sleep" && root.sleepWarms && Toggles.hasNight && !Toggles.night) {
            Toggles.toggleNight();
            root.startedNight = true;
        }
        if (id === "gaming" && root.gamingGameMode && !GameMode.on) {
            GameMode.setOn(true);
            root.startedGame = true;
        }
    }

    function leave() {
        if (root.startedNight && Toggles.night)
            Toggles.toggleNight();
        if (root.startedGame && GameMode.on)
            GameMode.setOn(false);
        root.startedNight = false;
        root.startedGame = false;
    }

    // How long it lasts, as the control centre says it.
    readonly property string untilLabel: {
        if (!root.on)
            return "";
        if (root.until <= 0)
            return "until turned off";
        const end = new Date(root.until);
        const hm = Time.clockOf(end, Time.twelveHour);
        return end.toDateString() === Time.now.toDateString() ? `until ${hm}` : `until tomorrow ${hm}`;
    }

    /*
     * Ending on time. Checked against the wall clock rather than counted down,
     * so a laptop asleep past the end wakes up out of the mode, and on every
     * tick of the shell's clock, which the lock nudges on waking.
     */
    function expire() {
        if (root.on && root.until > 0 && Date.now() >= root.until)
            root.stop();
    }

    Connections {
        target: Time

        function onNowChanged() {
            root.expire();
        }
    }

    Timer {
        running: root.on && root.until > 0
        repeat: true
        interval: 20000
        onTriggered: root.expire()
    }
}
