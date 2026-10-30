pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

/*
 * The subject of each wallpaper, cut out on its own transparent layer.
 *
 * Made automatically with rembg whenever a wallpaper is in use and has no cutout
 * yet, one image at a time and at low priority, and kept in the cache directory
 * so each picture is only ever processed once. Until one exists the desktop shows
 * the flat wallpaper, and nothing waits on it.
 *
 * rembg downloads its model the first time it runs, which is a one-off.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.get("wallpaper.cutout", true)
    readonly property string model: Config.get("wallpaper.cutoutModel", "isnet-general-use")
    readonly property string cacheDir: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/stratum/cutouts`

    // Found with the user's own bin directories on the path (pipx puts it in
    // ~/.local/bin, which the shell's own environment often lacks).
    property string binary: ""
    readonly property bool available: root.binary.length > 0
    // Image path -> cutout path, for the ones that exist.
    property var done: ({})
    property string working: ""
    property string error: ""

    // Every picture currently on a monitor, once each.
    readonly property var wanted: {
        const seen = new Set();
        for (const screen of Quickshell.screens) {
            const path = Wallpaper.forMonitor(screen.name);
            if (path)
                seen.add(path);
        }
        return Array.from(seen);
    }

    readonly property string status: {
        if (!root.enabled)
            return "off";
        if (!root.available)
            return "needs rembg";
        if (root.error.length > 0)
            return root.error;
        return root.working.length > 0 ? "making cutout…" : "ready";
    }

    onWantedChanged: root.pump()
    onEnabledChanged: root.pump()

    // A short stable name for an image, so its cutout can be found again.
    function key(path) {
        let h = 5381;
        for (let i = 0; i < path.length; i++)
            h = ((h << 5) + h + path.charCodeAt(i)) | 0;
        return (h >>> 0).toString(16);
    }

    function outFor(path) {
        return `${root.cacheDir}/${root.key(path)}.png`;
    }

    function urlFor(monitor) {
        const cut = root.done[Wallpaper.forMonitor(monitor)];
        return root.enabled && cut ? `file://${cut}` : "";
    }

    function pump() {
        if (!root.enabled || !root.available || maker.running)
            return;
        const next = root.wanted.find(p => !root.done[p] && p !== root.failed);
        if (!next)
            return;
        root.working = next;
        maker.command = ["sh", "-c",
            `out="$2"; mkdir -p "$(dirname "$out")"; ` +
            `[ -s "$out" ] || { nice -n 19 "$4" i -m "$3" "$1" "$out.tmp" && mv "$out.tmp" "$out"; }; ` +
            `[ -s "$out" ]`,
            "sh", next, root.outFor(next), root.model, root.binary];
        maker.running = true;
    }

    property string failed: ""

    Process {
        id: probe

        running: true
        command: ["sh", "-c", Bin.finder, "sh", "rembg"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.binary = text.trim();
                root.pump();
            }
        }
    }

    Process {
        id: maker

        stderr: StdioCollector {
            onStreamFinished: {
                const last = text.trim().split("\n").filter(l => l.length > 0).pop() ?? "";
                if (maker.exitCode !== 0 && last.length > 0)
                    root.error = last;
            }
        }

        onExited: (code, status) => {
            const path = root.working;
            root.working = "";
            if (code === 0) {
                const next = Object.assign({}, root.done);
                next[path] = root.outFor(path);
                root.done = next;
                root.error = "";
            } else {
                // Not retried for the rest of this session, or a picture rembg
                // cannot handle would be tried again forever.
                root.failed = path;
            }
            root.pump();
        }
    }
}
