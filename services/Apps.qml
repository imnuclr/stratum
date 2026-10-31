pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

/*
 * "Open this app" as a key would want it: the app's window, here, now.
 *
 * If a window of the app is open anywhere — another workspace, a scratchpad
 * (special workspace), another monitor — it is brought to the workspace you are
 * on and focused, as an ordinary window. If none is, the app is started with
 * Hyprland told to open it on this workspace, which wins over a window rule
 * sending it to a scratchpad, so it never shows up there first. Its window is
 * still pulled here if it appears elsewhere anyway.
 *
 *     qs -c stratum ipc call apps open spotify
 */
Singleton {
    id: root

    // Waiting for a just-started app's window, as { entry, until }.
    property var waiting: null

    function entryFor(name) {
        const q = String(name).toLowerCase().replace(/\.desktop$/, "");
        const all = DesktopEntries.applications?.values ?? [];
        return DesktopEntries.byId(q)
            ?? all.find(e => e.id.toLowerCase() === q)
            ?? all.find(e => e.id.toLowerCase().split(".").includes(q))
            ?? all.find(e => e.name.toLowerCase() === q)
            ?? all.find(e => e.name.toLowerCase().startsWith(q))
            ?? null;
    }

    function words(text) {
        return String(text ?? "").toLowerCase().split(/[^a-z0-9]+/)
            .filter(w => w.length > 2 && !["com", "org", "desktop", "client", "app", "bin", "the"].includes(w));
    }

    // Names a window of this app could carry as its class.
    function namesOf(entry, name) {
        return new Set([...root.words(name), ...root.words(entry?.id), ...root.words(entry?.name),
            ...root.words(entry?.startupClass), ...root.words(String(entry?.execString ?? "").split(" ")[0].split("/").pop())]);
    }

    // launch false: only bring a window that exists or turns up soon (a
    // notification's own action is starting the app); never start it here.
    function open(name, launch) {
        root.pending = { name: name, entry: root.entryFor(name), launch: launch !== false };
        monitors.running = false;
        monitors.running = true;
    }

    // The focused monitor's ordinary workspace, and the scratchpad open over it
    // if there is one. Hyprland counts a shown scratchpad as the focused
    // workspace, so asking for "the current workspace" moved the window right
    // back into the scratchpad it was being rescued from.
    property int here: 1
    property string overlay: ""

    Process {
        id: monitors

        command: ["hyprctl", "monitors", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const m = JSON.parse(text).find(x => x.focused);
                    root.here = m?.activeWorkspace?.id ?? root.here;
                    root.overlay = (m?.specialWorkspace?.name ?? "").replace(/^special:/, "");
                } catch (e) {}
                clients.running = false;
                clients.running = true;
            }
        }
    }

    property var pending: null

    function quote(word) {
        return "'" + String(word).replace(/'/g, "'\\''") + "'";
    }

    /*
     * Starts the app on the workspace in front of you. The workspace goes in an
     * exec rule on the launch itself: a window rule has only the app's class to
     * go on, and an exec rule beats it.
     */
    function start(job) {
        const cmd = job.entry?.command?.length > 0
            ? job.entry.command.map(root.quote).join(" ")
            : job.name;
        // A scratchpad left open would hide the window as it appears.
        if (root.overlay.length > 0) {
            Hyprland.dispatch(Hypr.lua
                ? `hl.dsp.workspace.toggle_special("${root.overlay}")`
                : `togglespecialworkspace ${root.overlay}`);
            root.overlay = "";
        }
        const line = `[workspace ${root.here}] ${cmd}`;
        Hyprland.dispatch(Hypr.lua ? `hl.dsp.exec_cmd(${JSON.stringify(line)})` : `exec ${line}`);
    }

    function bring(client) {
        const here = root.here;
        const addr = client.address;
        // Put the scratchpad away first, so the window lands on the workspace
        // underneath and that is what is showing.
        if (root.overlay.length > 0) {
            Hyprland.dispatch(Hypr.lua
                ? `hl.dsp.workspace.toggle_special("${root.overlay}")`
                : `togglespecialworkspace ${root.overlay}`);
            root.overlay = "";
        }
        if (client.workspace?.id !== here) {
            Hyprland.dispatch(Hypr.lua
                ? `hl.dsp.window.move({ window = "address:${addr}", workspace = "${here}", follow = false })`
                : `movetoworkspacesilent ${here},address:${addr}`);
        }
        Hypr.focusWindow(addr);
    }

    Process {
        id: clients

        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {}
                const job = root.pending ?? root.waiting;
                if (!job)
                    return;
                const names = root.namesOf(job.entry, job.name);
                const hit = list.find(c => [...root.words(c.class), ...root.words(c.initialClass)].some(w => names.has(w)));
                if (hit) {
                    root.bring(hit);
                    root.waiting = null;
                } else if (root.pending) {
                    // Not running: start it, then watch for its window.
                    if (job.launch)
                        root.start(job);
                    root.waiting = { name: job.name, entry: job.entry, tries: 0 };
                    watch.restart();
                }
                root.pending = null;
            }
        }
    }

    /*
     * A window opening while one is awaited is looked for at once rather than
     * on the next tick. An app already running in the background (a chat app
     * closed to its tray) makes its window itself, so the launch's workspace
     * never applies to it and a window rule may put it in a scratchpad; the
     * sooner it is pulled out, the less of that is seen.
     */
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "openwindow" || !root.waiting || root.pending)
                return;
            monitors.running = false;
            monitors.running = true;
        }
    }

    // Looks for the new window for a while after starting it.
    Timer {
        id: watch

        interval: 250
        repeat: true
        onTriggered: {
            if (!root.waiting || root.waiting.tries++ > 80) {
                root.waiting = null;
                watch.stop();
                return;
            }
            // Through the monitors again: a rule may have opened the scratchpad
            // along with the new window.
            monitors.running = false;
            monitors.running = true;
        }
    }
}
