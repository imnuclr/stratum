pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*
 * The widgets on the desktop: which ones, where, and how big.
 *
 * Positions are in grid cells, not pixels, so a layout survives a change of scale
 * and snapping is just rounding. Each monitor has a layout of its own, because a
 * desktop arranged for an ultrawide is not one arranged for a laptop. The file is
 * machine-written (widgets.json beside the other config); a monitor that has never
 * been arranged gets a default laid out for its width, and only becomes part of
 * the file once something on it is changed.
 */
Singleton {
    id: root

    // Edit mode: the grid shows and widgets can be moved, resized, added, removed.
    property bool editing: false

    // One grid cell, in pixels. Fine enough to place things where they look right,
    // coarse enough that snapping does something.
    readonly property real cell: 20

    // What can be placed. `shape` says what sits behind a widget: nothing, a
    // rounded tile, or a disc.
    readonly property var types: ({
        "clock": { label: "clock", icon: "moon", w: 54, h: 26, minW: 24, minH: 10, shape: "none" },
        "greeting": { label: "greeting", icon: "sun", w: 44, h: 14, minW: 22, minH: 6, shape: "none" },
        "weather": { label: "weather", icon: "cloud-sun", w: 15, h: 15, minW: 9, minH: 9, shape: "round" },
        "date": { label: "date", icon: "app", w: 15, h: 15, minW: 9, minH: 9, shape: "tile" },
        "gpu": { label: "gpu", icon: "scan", w: 15, h: 15, minW: 9, minH: 9, shape: "round" },
        "media": { label: "now playing", icon: "play", w: 31, h: 15, minW: 20, minH: 10, shape: "tile" },
        "stats": { label: "system", icon: "terminal", w: 47, h: 15, minW: 26, minH: 10, shape: "tile" }
    })
    readonly property var typeNames: ["clock", "greeting", "weather", "date", "gpu", "media", "stats"]

    // monitor name -> [{ id, type, x, y, w, h }]
    property var layouts: ({})

    readonly property string path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/stratum/widgets.json`

    function uid() {
        return Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36);
    }

    function make(type, x, y) {
        const t = root.types[type];
        return { id: root.uid(), type: type, x: x, y: y, w: t.w, h: t.h };
    }

    // Laid out for a screen `cols` cells across: the clock and greeting at the left,
    // a column of small things at the right.
    function defaultLayout(cols) {
        // The small things in a block at the right, three rows of tiles one cell
        // apart; the clock and greeting at the left.
        const x0 = Math.max(58, cols - 48);
        const list = [
            root.make("clock", 3, 9),
            root.make("greeting", 3, 42),
            root.make("weather", x0, 10),
            root.make("date", x0 + 16, 10),
            root.make("gpu", x0 + 32, 10),
            root.make("media", x0, 26),
            root.make("stats", x0, 42)
        ];
        // Stable ids, so a default is the same default each time it is asked for.
        list.forEach(w => w.id = `default-${w.type}`);
        return list;
    }

    function layoutFor(name, cols) {
        return root.layouts[name] ?? root.defaultLayout(cols ?? 100);
    }

    function commit(name, list) {
        const next = Object.assign({}, root.layouts);
        next[name] = list;
        root.layouts = next;
        writer.restart();
    }

    // Edits start from what is showing, so the first change on a monitor writes its
    // default out and everything after works on the real thing.
    function edit(name, cols, change) {
        const list = root.layoutFor(name, cols).map(w => Object.assign({}, w));
        change(list);
        root.commit(name, list);
    }

    function move(name, cols, id, x, y) {
        root.edit(name, cols, list => {
            const w = list.find(i => i.id === id);
            if (w) {
                w.x = Math.max(0, Math.round(x));
                w.y = Math.max(0, Math.round(y));
            }
        });
    }

    function resize(name, cols, id, w, h) {
        root.edit(name, cols, list => {
            const it = list.find(i => i.id === id);
            if (!it)
                return;
            const t = root.types[it.type];
            it.w = Math.max(t.minW, Math.round(w));
            it.h = Math.max(t.minH, Math.round(h));
        });
    }

    function remove(name, cols, id) {
        root.edit(name, cols, list => {
            const at = list.findIndex(i => i.id === id);
            if (at >= 0)
                list.splice(at, 1);
        });
    }

    function add(name, cols, type) {
        root.edit(name, cols, list => {
            // Somewhere visible and not exactly on top of the last one.
            const n = list.length;
            list.push(root.make(type, 8 + (n % 5) * 2, 6 + (n % 5) * 2));
        });
    }

    function reset(name) {
        const next = Object.assign({}, root.layouts);
        delete next[name];
        root.layouts = next;
        writer.restart();
    }

    Timer {
        id: writer

        interval: 400
        onTriggered: file.setText(JSON.stringify({ layouts: root.layouts }, null, 2) + "\n")
    }

    FileView {
        id: file

        path: root.path
        preload: true
        // A missing file is the first run, not a fault.
        onLoadFailed: root.layouts = ({})
        onLoaded: {
            try {
                const data = JSON.parse(file.text());
                root.layouts = data.layouts ?? ({});
            } catch (e) {
                console.log(`[widgets] ${root.path} is not valid JSON; using defaults`);
                root.layouts = ({});
            }
        }
    }
}
