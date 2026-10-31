pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services

/*
 * How Hyprland draws windows, as chosen in Settings → Appearance: the blur
 * behind see-through windows, and how strong it is.
 *
 * "As in your config" leaves Hyprland alone. Anything else is applied live and
 * put back after every config reload, since a reload resets it. An energy
 * saver that turns effects off wins while it is on.
 */
Singleton {
    id: root

    /*
     * Blur as a percentage, 0 for none, or "config" to leave Hyprland's own.
     * The named strengths of earlier versions are read as their percentages.
     */
    readonly property var presets: ({ off: 0, light: 30, medium: 60, strong: 90 })
    readonly property var raw: Config.get("windows.blur", "config")
    readonly property string blur: root.raw === "config" ? "config" : "custom"
    readonly property int amount: typeof root.raw === "number"
        ? Math.max(0, Math.min(100, Math.round(root.raw)))
        : (root.presets[root.raw] ?? 60)

    function setAmount(percent) {
        Config.set("windows.blur", Math.max(0, Math.min(100, Math.round(percent))));
    }

    onAmountChanged: blurLater.restart()

    // Dragging the slider changes it many times a second; Hyprland is asked
    // once it settles.
    Timer {
        id: blurLater

        interval: 120
        onTriggered: root.apply()
    }

    onBlurChanged: root.apply()
    Component.onCompleted: {
        root.apply();
        root.paintBorders();
    }

    /*
     * Window borders and their glow in the shell's colours: the accent running
     * into the tertiary across active windows, a quiet surface tone on the rest,
     * and the shadow tinted to match — so the edge of a window agrees with
     * everything inside it. "config" leaves your own border colours alone.
     */
    readonly property string borders: Config.get("windows.borders", "accent")

    /*
     * How much glow sits around a window, as a percentage: 0 is none, 100 a
     * wide, bright halo. Strength spreads it and deepens its colour at once,
     * which is what reads as "more glow"; past about 70 it also lifts off the
     * window a little, the way a light source would.
     */
    readonly property int glow: Math.max(0, Math.min(100, Config.get("windows.glow", 40)))
    readonly property int glowSize: Math.round(2 + root.glow * 0.38)
    readonly property int glowRange: Math.round(2 + root.glow * 0.18)
    // 00 to about dd, as two hex digits.
    readonly property string glowAlpha: Math.round(Math.min(221, root.glow * 2.2)).toString(16).padStart(2, "0")
    readonly property var colours: AppTheme.palette

    onGlowChanged: paint.restart()

    onBordersChanged: {
        if (root.borders === "config")
            Quickshell.execDetached(["hyprctl", "reload"]);
        else
            paint.restart();
    }
    onColoursChanged: paint.restart()

    Timer {
        id: paint

        interval: 300
        onTriggered: root.paintBorders()
    }

    // #rrggbb and an alpha as Hyprland's rgba(rrggbbaa).
    function rgba(hex, alpha) {
        return `rgba(${String(hex).slice(1, 7)}${alpha})`;
    }

    function paintBorders() {
        if (root.borders === "config" || GameMode.on)
            return;
        const c = root.colours;
        const active = `${root.rgba(c.accent, "ff")} ${root.rgba(c.tertiary, "ff")} 45deg`;
        const inactive = root.rgba(c.bgTop, "aa");
        const glow = root.rgba(c.accent, root.glowAlpha);
        const on = root.glow > 0;
        if (Hypr.lua) {
            /*
             * The glow took and the borders did not: a gradient written as one
             * string is not what the Lua config takes. A single colour is sent
             * first, which it does take, then the gradient as a table; if that
             * form is refused too, the solid colour stays.
             */
            const solid = root.rgba(c.accent, "ff");
            Hypr.runLua([
                `hl.config({ decoration = { shadow = { enabled = ${on}, color = "${glow}", size = ${root.glowSize}, range = ${root.glowRange}, render_power = 3, offset = "0 0" } } })`,
                `hl.config({ general = { col = { active_border = "${solid}", inactive_border = "${inactive}" } } })`,
                // The gradient as a table (a "a b 45deg" string is refused in
                // Lua); the solid colour above stays if this is refused too.
                `hl.config({ general = { col = { active_border = { colors = { "${solid}", "${root.rgba(c.tertiary, "ff")}" }, angle = 45 } } } })`
            ]);
        } else {
            Quickshell.execDetached(["hyprctl", "--batch",
                `keyword general:col.active_border ${active} ; keyword general:col.inactive_border ${inactive}`
                + ` ; keyword decoration:shadow:enabled ${on ? 1 : 0} ; keyword decoration:shadow:color ${glow}`
                + ` ; keyword decoration:shadow:size ${root.glowSize} ; keyword decoration:shadow:range ${root.glowRange}`]);
        }
    }

    function apply() {
        if (root.blur === "config" || Power.noEffects || GameMode.on)
            return;
        // 1% is a whisper of blur, 100% a heavy frosted glass: the radius
        // grows steadily and more passes are added as it does.
        const on = root.amount > 0;
        const s = { size: Math.max(1, Math.round(1 + root.amount * 0.15)), passes: Math.max(1, Math.min(4, 1 + Math.floor(root.amount / 30))) };
        if (Hypr.lua) {
            Hypr.configure(on
                ? `{ decoration = { blur = { enabled = true, size = ${s.size}, passes = ${s.passes} } } }`
                : "{ decoration = { blur = { enabled = false } } }");
        } else {
            Quickshell.execDetached(["hyprctl", "--batch", on
                ? `keyword decoration:blur:enabled 1 ; keyword decoration:blur:size ${s.size} ; keyword decoration:blur:passes ${s.passes}`
                : "keyword decoration:blur:enabled 0"]);
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.apply();
                root.paintBorders();
            }
        }
    }
}
