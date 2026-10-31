pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config
import qs.services
import qs.theme

/*
 * Everything out of the way of a game, from one switch in the control centre.
 *
 * On: Hyprland stops animating, blurring and drawing shadows (the compositor's
 * share of the GPU), the power profile goes to performance, notifications hold
 * themselves (do not disturb), the screen is kept awake, and the shell's own
 * background work stops — desktop widgets stop polling and hide, the wallpaper
 * stops drifting, panels stop animating.
 *
 * Off: each of those goes back to what it was before, not to a default — if do
 * not disturb was already on, it stays on.
 */
Singleton {
    id: root

    property bool on: false
    // What was in place before, to put back.
    property var before: ({})

    function toggle() {
        root.setOn(!root.on);
    }

    function setOn(value) {
        if (value === root.on)
            return;
        if (value) {
            root.before = {
                profile: Power.profile,
                dnd: Notifs.dnd,
                caffeine: Toggles.caffeine
            };
            if (Power.profiles.includes("performance"))
                Power.setProfile("performance");
            if (!Notifs.dnd)
                Notifs.toggleDnd();
            if (!Toggles.caffeine)
                Toggles.toggleCaffeine();
            root.on = true;
            root.quietCompositor();
        } else {
            root.on = false;
            const b = root.before;
            if (b.profile)
                Power.setProfile(b.profile);
            if (Notifs.dnd !== b.dnd)
                Notifs.toggleDnd();
            if (Toggles.caffeine !== b.caffeine)
                Toggles.toggleCaffeine();
            // A reload puts back exactly what your config says; the shell's own
            // blur and saver choices are applied again on top by Decor and Power.
            Quickshell.execDetached(["hyprctl", "reload"]);
        }
    }

    function quietCompositor() {
        if (Hypr.lua) {
            Hypr.configure("{ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false } } }");
        } else {
            Quickshell.execDetached(["hyprctl", "--batch",
                "keyword animations:enabled 0 ; keyword decoration:blur:enabled 0 ; keyword decoration:shadow:enabled 0"]);
        }
    }

    // A reload while gaming (from anywhere) would bring the effects back.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (root.on && event.name === "configreloaded")
                root.quietCompositor();
        }
    }

    // The shell's own animations stop with the compositor's.
    Binding {
        target: Theme
        property: "gaming"
        value: root.on
    }
}
