pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*
 * Resolved design tokens. Layering, lowest to highest precedence:
 *   presets/<preset>.json  <-  ~/.config/stratum/theme.json  <-  generated/palette.json
 *
 * Every visual value in the shell comes from here. No module hardcodes a colour,
 * a radius, or a duration.
 */
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/stratum`

    property bool ready: false
    property string error: ""
    property var tokens: ({})

    // --- colour ---
    readonly property color bg: pick("color.bg", "#09090A")
    readonly property color panel: pick("color.panel", "#0B0B0C")
    readonly property color surface: pick("color.surface", "#141416")
    readonly property color surfaceHi: pick("color.surfaceHi", "#1D1D20")
    readonly property color surfaceTop: pick("color.surfaceTop", "#232327")
    readonly property color line: pick("color.line", "#12FFFFFF")
    readonly property color lineHi: pick("color.lineHi", "#24FFFFFF")
    readonly property color fg: pick("color.fg", "#F4F4F5")
    readonly property color fgDim: pick("color.fgDim", "#9A9AA0")
    readonly property color fgFaint: pick("color.fgFaint", "#5C5C62")
    readonly property color dotOn: pick("color.dotOn", "#FFFFFF")
    readonly property color dotOff: pick("color.dotOff", "#21FFFFFF")
    readonly property color accent: pick("color.accent", "#E5252B")

    // --- geometry ---
    readonly property int rTile: pick("radius.tile", 20)
    readonly property int rSheet: pick("radius.sheet", 28)
    readonly property int rInner: pick("radius.inner", 12)
    readonly property int rPill: 999

    function space(step) {
        const scale = pick("space", [4, 8, 12, 16, 24, 32, 48]);
        return scale[Math.max(0, Math.min(scale.length - 1, step))];
    }

    // --- type ---
    readonly property string fontDot: pick("font.display", "Doto")
    readonly property string fontUi: pick("font.ui", "Geist")
    readonly property string fontMono: pick("font.mono", "JetBrainsMono Nerd Font")

    // --- motion ---
    readonly property int micro: pick("motion.micro", 120)
    readonly property int standard: pick("motion.standard", 200)
    readonly property int sheetMs: pick("motion.sheet", 320)
    readonly property real dotStagger: pick("motion.dotStagger", 8)

    readonly property var enterEasing: pick("motion.enterEasing", [0.2, 0, 0, 1])
    readonly property var exitEasing: pick("motion.exitEasing", [0.3, 0, 0.8, 0.15])

    function pick(keyPath, fallback) {
        let node = tokens;
        for (const key of keyPath.split(".")) {
            if (node === undefined || node === null || typeof node !== "object")
                return fallback;
            node = node[key];
        }
        return node === undefined ? fallback : node;
    }

    function reload() {
        let user = {};
        if (userFile.text().trim().length > 0) {
            try {
                user = JSON.parse(userFile.text());
                root.error = "";
            } catch (e) {
                root.error = `${root.dir}/theme.json: ${e.message}`;
                root.ready = false;
                return;
            }
        }

        let preset = {};
        try {
            preset = JSON.parse(presetFile.text());
        } catch (e) {
            root.error = `preset "${presetName}" is malformed: ${e.message}`;
            return;
        }

        root.tokens = Config.merge(preset, user);
        root.ready = true;
    }

    readonly property string presetName: {
        if (userFile.text().trim().length === 0)
            return "nothing-dark";
        try {
            return JSON.parse(userFile.text()).preset ?? "nothing-dark";
        } catch (e) {
            return "nothing-dark";
        }
    }

    FileView {
        id: presetFile

        path: Quickshell.shellPath(`theme/presets/${root.presetName}.json`)
        blockLoading: true
        onLoaded: root.reload()
    }

    FileView {
        id: userFile

        path: `${root.dir}/theme.json`
        watchChanges: true
        preload: true
        onLoaded: root.reload()
        onFileChanged: reload()
        onLoadFailed: root.reload()
    }
}
