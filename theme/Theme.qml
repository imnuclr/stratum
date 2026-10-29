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

    /*
     * Which variant of the configured preset is live. The dark/light toggle sets
     * this, so the shell changes with it rather than only handing GTK apps a
     * gsettings key and staying dark itself.
     */
    property bool dark: true

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
    readonly property color fgBright: pick("color.fgBright", "#D2D2D8")
    readonly property color fgFaint: pick("color.fgFaint", "#5C5C62")
    readonly property color dotOn: pick("color.dotOn", "#FFFFFF")
    readonly property color dotOff: pick("color.dotOff", "#21FFFFFF")
    readonly property color accent: pick("color.accent", "#E5252B")

    // Semantic colours stay unused until something is genuinely wrong — a low
    // battery, an unroutable connection. They are not a second accent.
    readonly property color ok: pick("color.ok", "#4ADE80")
    readonly property color warn: pick("color.warn", "#FBBF24")
    readonly property color crit: pick("color.crit", "#EF4444")

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
    readonly property int sheetMs: pick("motion.sheet", 420)

    // How long a popout takes to resize, move and appear. Short enough to keep
    // up with a pointer crossing the bar, long enough not to crack.
    readonly property int popoutMs: pick("motion.popout", 320)
    readonly property real dotStagger: pick("motion.dotStagger", 8)

    /*
     * Bezier easing points. Qt requires these in multiples of six — two control
     * points plus the end point (1,1) per cubic segment. A list of any other
     * length is discarded outright and the curve silently animates linearly,
     * with no warning, which is what these did for their first few commits.
     */
    // Was [0.2, 0, 0, 1]: almost all of the travel in the first few frames, then
    // a long crawl. Fine on paper, and it read as a slam.
    readonly property var enterEasing: pick("motion.enterEasing", [0.215, 0.61, 0.355, 1, 1, 1])
    readonly property var exitEasing: pick("motion.exitEasing", [0.3, 0, 0.8, 0.15, 1, 1])
    // Overshoots slightly. For things that appear rather than merely move.
    readonly property var expressive: pick("motion.expressive", [0.34, 1.26, 0.38, 1, 1, 1])
    // Eased at both ends. For something changing size, where enterEasing's hard
    // decelerate puts most of the change in the first third and reads as a pop.
    readonly property var smooth: pick("motion.smooth", [0.4, 0, 0.2, 1, 1, 1])

    /*
     * Eased out, gently. The standard curve leaves at speed and stops dead,
     * which on a short duration reads as the panel being thrown at its position
     * rather than moving there. This one is ease-out-cubic: it starts moving
     * properly, slows the whole way, and has nothing abrupt at either end.
     */
    readonly property var gentle: pick("motion.gentle", [0.215, 0.61, 0.355, 1, 1, 1])
    readonly property int expressiveMs: pick("motion.expressiveMs", 420)

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

    /*
     * Swap a preset's variant suffix to match the current mode, so one setting
     * names a family ("nothing") and the toggle picks the half of it that is
     * live. A preset with no suffix is taken as mode-agnostic and left alone.
     */
    function variantOf(name) {
        const suffix = root.dark ? "-dark" : "-light";
        if (name.endsWith("-dark") || name.endsWith("-light"))
            return name.replace(/-(dark|light)$/, suffix);
        return name;
    }

    readonly property string presetName: {
        const fallback = root.variantOf("nothing-dark");
        if (userFile.text().trim().length === 0)
            return fallback;
        try {
            return root.variantOf(JSON.parse(userFile.text()).preset ?? "nothing-dark");
        } catch (e) {
            return fallback;
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
