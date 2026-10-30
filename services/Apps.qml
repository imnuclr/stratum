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
 * on and focused, as an ordinary window. If none is, the app is started, and
 * its window is pulled here when it appears, so a window rule sending it to a
 * scratchpad does not win.
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

    function open(name) {
        root.pending = { name: name, entry: root.entryFor(name) };
        clients.running = false;
        clients.running = true;
    }

    property var pending: null

    function currentWorkspace() {
        return Hypr.focusedWorkspace?.id ?? 1;
    }

    function bring(client) {
        const here = root.currentWorkspace();
        const addr = client.address;
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
                    if (job.entry)
                        job.entry.execute();
                    else
                        Quickshell.execDetached(["sh", "-c", job.name]);
                    root.waiting = { name: job.name, entry: job.entry, tries: 0 };
                    watch.restart();
                }
                root.pending = null;
            }
        }
    }

    // Looks for the new window for a while after starting it.
    Timer {
        id: watch

        interval: 500
        repeat: true
        onTriggered: {
            if (!root.waiting || root.waiting.tries++ > 30) {
                root.waiting = null;
                watch.stop();
                return;
            }
            clients.running = false;
            clients.running = true;
        }
    }
}
