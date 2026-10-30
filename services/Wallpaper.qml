pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*
 * Which image each monitor shows behind everything else.
 *
 * The shell draws the wallpaper itself rather than leaving it to swww or
 * hyprpaper, because it is the bottom layer of the same stack as the bar and the
 * panels: a crossfade between two images in one scene graph costs nothing, and a
 * separate daemon would be a second thing to configure, start and keep in step
 * with the theme.
 *
 * The choice is remembered in a state file rather than the config, so picking a
 * wallpaper at runtime never rewrites something the user hand-edits.
 */
Singleton {
    id: root

    // A config file written by hand says ~/Pictures, which no API expands.
    readonly property string dir: root.expand(Config.get("wallpaper.dir", "~/Pictures/Wallpapers"))

    function expand(path) {
        const home = Quickshell.env("HOME");
        if (path === "~")
            return home;
        return path.startsWith("~/") ? home + path.slice(1) : path;
    }
    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/stratum/wallpaper.json`

    // Every image in the directory, sorted: the pool next() and random() draw from.
    property var entries: []
    property bool ready: false

    // What a monitor shows when it has nothing of its own.
    property string current: ""
    // Monitors that have been given their own, by name.
    property var overrides: ({})

    function forMonitor(name) {
        return root.overrides[name] ?? root.current;
    }

    // Image.source wants a URL; everything else here keeps plain paths.
    function urlFor(name) {
        const path = root.forMonitor(name);
        return path ? `file://${path}` : "";
    }

    /*
     * Setting without naming a monitor sets all of them, and clears the
     * per-monitor choices: "set the wallpaper" means the whole desktop, and
     * leaving one display on something else would read as a bug.
     */
    function set(path, monitor) {
        if (!path)
            return;
        if (monitor) {
            const next = Object.assign({}, root.overrides);
            next[monitor] = path;
            root.overrides = next;
        } else {
            root.current = path;
            root.overrides = ({});
        }
        root.save();
    }

    // Steps through the directory from whatever is showing now.
    function cycle(step, monitor) {
        if (root.entries.length === 0)
            return;
        const showing = root.forMonitor(monitor ?? "");
        const at = root.entries.indexOf(showing);
        const count = root.entries.length;
        // An unknown current starts the walk at the beginning rather than nowhere.
        const to = at < 0 ? 0 : (at + step % count + count) % count;
        root.set(root.entries[to], monitor);
    }

    function random(monitor) {
        if (root.entries.length === 0)
            return;
        if (root.entries.length === 1) {
            root.set(root.entries[0], monitor);
            return;
        }
        // Never the one already showing: a shuffle that repeats looks broken.
        const showing = root.forMonitor(monitor ?? "");
        let pick = showing;
        while (pick === showing)
            pick = root.entries[Math.floor(Math.random() * root.entries.length)];
        root.set(pick, monitor);
    }

    function scan() {
        lister.running = true;
    }

    function save() {
        state.setText(JSON.stringify({
            current: root.current,
            monitors: root.overrides
        }, null, 4) + "\n");
    }

    Component.onCompleted: root.scan()
    onDirChanged: root.scan()

    Process {
        id: lister

        // The directory is config, so it is passed as an argument rather than
        // spliced into the script.
        command: ["sh", "-c", 'find "$1" -maxdepth 1 -type f \\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \\) | sort', "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.trim().length > 0 ? text.trim().split("\n") : [];
                root.ready = true;
                // Nothing chosen yet, or the chosen file is gone: start somewhere.
                if (root.entries.length > 0 && root.entries.indexOf(root.current) < 0)
                    root.set(root.entries[0]);
            }
        }
    }

    FileView {
        id: state

        path: root.statePath
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.current = data.current ?? "";
                root.overrides = data.monitors ?? ({});
            } catch (e) {
                // Unreadable: the scan below will pick something.
            }
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => state.setText("{}\n"));
        }
    }
}
