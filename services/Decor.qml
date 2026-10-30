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
    Component.onCompleted: root.apply()

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
            if (event.name === "configreloaded")
                root.apply();
        }
    }
}
