pragma Singleton

import QtQuick
import Quickshell
import qs.config

/*
 * What the on-screen indicator is saying, and for how long.
 *
 * Asked for by the keys that change something with no other sign of it — volume,
 * brightness, the mic — and by nothing else, so it is only ever a reply to a key
 * press. The level shown is the one the key is going to, worked out by the caller:
 * the real value arrives a moment later, and an indicator that waited for it would
 * show the old number.
 */
Singleton {
    id: root

    property string icon: ""
    property string label: ""
    // 0 to 1, or -1 for something that has no level (mic on or off).
    property real level: -1
    property bool dim: false
    // Bumped by every show(), so the window can tell "again" from "still".
    property int serial: 0
    property bool shown: false

    function show(icon, label, level, dim) {
        if (!Config.get("osd.enabled", true))
            return;
        root.icon = icon;
        root.label = label;
        root.level = level;
        root.dim = dim ?? false;
        root.serial++;
        root.shown = true;
        hide.restart();
    }

    function volume(level, muted) {
        const l = Math.max(0, Math.min(1, level));
        root.show(muted ? "volume-mute" : (l >= 0.5 ? "volume-2" : (l > 0 ? "volume-1" : "volume-0")),
            muted ? "muted" : `${Math.round(l * 100)}`, muted ? 0 : l, muted);
    }

    function brightness(level) {
        const l = Math.max(0, Math.min(1, level));
        root.show("brightness", `${Math.round(l * 100)}`, l, false);
    }

    function mic(muted) {
        root.show(muted ? "mic-off" : "mic", muted ? "mic off" : "mic on", -1, muted);
    }

    Timer {
        id: hide

        interval: 1300
        onTriggered: root.shown = false
    }
}
