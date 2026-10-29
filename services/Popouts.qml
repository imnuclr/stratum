pragma Singleton

import QtQuick
import Quickshell

/*
 * Hover popouts for bar items.
 *
 * Separate from Shell.openPanel on purpose: popouts are transient and
 * hover-driven, they never take keyboard focus, and one may replace another
 * without closing first — which is what lets the container slide and resize
 * between them instead of blinking.
 *
 * The grace timer is what makes them usable: leaving the bar item starts a short
 * countdown rather than closing, so the pointer can travel into the popout.
 */
Singleton {
    id: root

    property string current: ""
    property string monitorName: ""
    // Centre of the hovered item, in bar-window coordinates.
    property real anchorX: 0

    readonly property bool open: current.length > 0

    function show(name, x, monitor) {
        hideTimer.stop();
        current = name;
        anchorX = x;
        monitorName = monitor;
    }

    function requestHide() {
        hideTimer.restart();
    }

    function keepOpen() {
        hideTimer.stop();
    }

    function hide() {
        hideTimer.stop();
        current = "";
    }

    Timer {
        id: hideTimer

        interval: 180
        onTriggered: root.current = ""
    }
}
