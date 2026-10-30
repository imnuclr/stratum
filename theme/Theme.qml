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
    // Colours worked out from the wallpaper (services/Palette.qml), laid over
    // everything else when that is switched on, and empty when it is not.
    property var generated: ({})
    onGeneratedChanged: root.tokens = Config.merge(Config.merge(root.preset, root.user), root.generated)

    // The user's overrides held in memory, for the same reason Config holds its
    // own: a write that has not landed must not be overwritten by a re-read.
    property var user: ({})
    property var preset: ({})
    property bool dirty: false

    // --- colour ---
    readonly property color bg: pick("color.bg", "#080808")
    readonly property color panel: pick("color.panel", "#0B0B0B")
    readonly property color surface: pick("color.surface", "#121212")
    readonly property color surfaceHi: pick("color.surfaceHi", "#1B1B1B")
    readonly property color surfaceTop: pick("color.surfaceTop", "#242424")
    readonly property color line: pick("color.line", "#12FFFFFF")
    readonly property color lineHi: pick("color.lineHi", "#24FFFFFF")
    readonly property color fg: pick("color.fg", "#F5F5F5")
    readonly property color fgDim: pick("color.fgDim", "#9C9C9C")
    readonly property color fgBright: pick("color.fgBright", "#D6D6D6")
    readonly property color fgFaint: pick("color.fgFaint", "#5E5E5E")
    readonly property color dotOn: pick("color.dotOn", "#FFFFFF")
    readonly property color dotOff: pick("color.dotOff", "#21FFFFFF")
    readonly property color accent: pick("color.accent", "#E5252B")
    // Notifications: blacker than any surface, drawn with a pale outline.
    readonly property color deep: pick("color.deep", "#030303")
    readonly property color outline: pick("color.outline", "#D9FFFFFF")
    // Something has gone wrong. Not the accent, which is a decoration you may have
    // changed to white: an error must still read as one.
    readonly property color danger: pick("color.danger", "#E5252B")

    // Semantic colours stay unused until something is genuinely wrong — a low
    // battery, an unroutable connection. They are not a second accent.
    readonly property color ok: pick("color.ok", "#4ADE80")
    readonly property color warn: pick("color.warn", "#FBBF24")
    readonly property color crit: pick("color.crit", "#EF4444")

    // --- dots ---
    // One dot, everywhere: rings, bars, fields, icons and dividers all draw
    // their dots this size and this far apart, and a larger ring has more dots
    // rather than bigger ones. Pictures (album art, the wallpaper) are the
    // exception, because there the dot size is the picture's resolution.
    readonly property real dot: pick("dot.size", 4)
    readonly property real dotPitch: pick("dot.pitch", 8)

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
    // The lock screen's clock and greeting. Soft and round, where Doto is dots.
    readonly property string fontRounded: pick("font.rounded", "Nunito")

    // --- motion ---
    readonly property int micro: pick("motion.micro", 70)
    readonly property int standard: pick("motion.standard", 100)
    readonly property int sheetMs: pick("motion.sheet", 220)

    // How long a popout takes to appear, resize and move between triggers. Leaving
    // is shorter: something arriving is watched, something leaving is already
    // being left, and a slow exit reads as the panel refusing to go.
    readonly property int popoutMs: pick("motion.popout", 220)
    readonly property int popoutExitMs: pick("motion.popoutExit", 130)
    readonly property real dotStagger: pick("motion.dotStagger", 5)

    /*
     * Bezier easing points. Qt requires these in multiples of six — two control
     * points plus the end point (1,1) per cubic segment. A list of any other
     * length is discarded outright and the curve silently animates linearly,
     * with no warning, which is what these did for their first few commits.
     */
    // Large surfaces: sheets, popouts, toasts, the wallpaper fade. Both directions
    // use `soft`. The previous pair — ease-out-cubic in, ease-in out — measured
    // 40% of the travel inside the first 15% of the time on the way in, and the
    // way out accelerated into a dead stop. Both read as aggressive.
    readonly property var enterEasing: pick("motion.enterEasing", [0.37, 0, 0.63, 1, 1, 1])
    readonly property var exitEasing: pick("motion.exitEasing", [0.37, 0, 0.63, 1, 1, 1])
    // Overshoots slightly. For things that appear rather than merely move.
    readonly property var expressive: pick("motion.expressive", [0.34, 1.26, 0.38, 1, 1, 1])
    // Eased at both ends. For something changing size, where enterEasing's hard
    // decelerate puts most of the change in the first third and reads as a pop.
    readonly property var smooth: pick("motion.smooth", [0.4, 0, 0.2, 1, 1, 1])

    /*
     * Sine in-out: leaves from rest, peaks at about 1.6x the average speed, and
     * arrives at rest. Measured against ease-out-cubic, which peaks at 2.8x and has
     * covered 40% of its distance after 15% of its time. Use for anything large
     * enough that its motion is watched.
     */
    readonly property var soft: pick("motion.soft", [0.37, 0, 0.63, 1, 1, 1])

    /*
     * Eased out, for small feedback only: a press, a hover lift, a colour. At
     * that size and 120-200ms a slow start would read as lag, so this one leaves
     * at once. It is ease-out-cubic, and is too front-loaded for anything big —
     * use `soft` for those.
     */
    readonly property var gentle: pick("motion.gentle", [0.215, 0.61, 0.355, 1, 1, 1])
    readonly property int expressiveMs: pick("motion.expressiveMs", 220)

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

        root.preset = preset;
        if (!root.dirty)
            root.user = user;
        root.tokens = Config.merge(Config.merge(preset, root.user), root.generated);
        root.ready = true;
    }

    /*
     * Persists one override on top of the preset, e.g. setUser("color.accent",
     * "#3B82F6"). Refuses when theme.json could not be read, so a typo mid-edit
     * is never overwritten.
     */
    function setUser(keyPath, value) {
        if (root.error.length > 0)
            return false;

        const keys = keyPath.split(".");
        const next = JSON.parse(JSON.stringify(root.user));
        let node = next;
        for (const key of keys.slice(0, -1)) {
            if (!node[key] || typeof node[key] !== "object" || Array.isArray(node[key]))
                node[key] = {};
            node = node[key];
        }
        node[keys[keys.length - 1]] = value;
        root.commitUser(next);
        return true;
    }

    // Drops an override so the preset's own value shows through again.
    function clearUser(keyPath) {
        if (root.error.length > 0)
            return false;

        const keys = keyPath.split(".");
        const next = JSON.parse(JSON.stringify(root.user));
        const trail = [next];
        let node = next;
        for (const key of keys.slice(0, -1)) {
            if (!node[key] || typeof node[key] !== "object")
                return true;
            node = node[key];
            trail.push(node);
        }
        delete node[keys[keys.length - 1]];
        for (let i = trail.length - 1; i > 0; i--) {
            if (Object.keys(trail[i]).length > 0)
                break;
            delete trail[i - 1][keys[i - 1]];
        }
        root.commitUser(next);
        return true;
    }

    function commitUser(next) {
        root.user = next;
        root.dirty = true;
        root.tokens = Config.merge(Config.merge(root.preset, next), root.generated);
        writer.restart();
    }

    Timer {
        id: writer

        interval: 300
        onTriggered: userFile.setText(JSON.stringify(root.user, null, 2) + "\n")
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
        onSaved: root.dirty = false
    }
}
