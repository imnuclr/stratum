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

    // "config", "off", "light", "medium" or "strong".
    readonly property string blur: Config.get("windows.blur", "config")
    readonly property var strengths: ({
        light: { size: 4, passes: 2 },
        medium: { size: 8, passes: 3 },
        strong: { size: 12, passes: 4 }
    })

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
    readonly property var colours: AppTheme.palette

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
        const glow = root.rgba(c.accent, "55");
        if (Hypr.lua) {
            Hyprland.dispatch(`hl.config({ general = { col = { active_border = "${active}", inactive_border = "${inactive}" } }, decoration = { shadow = { color = "${glow}" } } })`);
        } else {
            Quickshell.execDetached(["hyprctl", "--batch",
                `keyword general:col.active_border ${active} ; keyword general:col.inactive_border ${inactive} ; keyword decoration:shadow:color ${glow}`]);
        }
    }

    function apply() {
        if (root.blur === "config" || Power.noEffects || GameMode.on)
            return;
        const on = root.blur !== "off";
        const s = root.strengths[root.blur] ?? root.strengths.medium;
        if (Hypr.lua) {
            Hyprland.dispatch(on
                ? `hl.config({ decoration = { blur = { enabled = true, size = ${s.size}, passes = ${s.passes} } } })`
                : `hl.config({ decoration = { blur = { enabled = false } } })`);
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
