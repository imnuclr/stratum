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

    // The content to render, which lags `current` by holding the last real name
    // through the close transition. The popout frame shrinks on the way out, and
    // emptying it first would collapse the frame before it has finished.
    // Initialised from current rather than empty: the handler below only fires on
    // a change, so a popout already open across a config reload would render an
    // empty frame. The first assignment replaces this binding.
    property string content: current

    onCurrentChanged: {
        if (current.length > 0)
            content = current;
    }

    function show(name, x, monitor) {
        hideTimer.stop();
        current = name;
        anchorX = x;
        monitorName = monitor;
    }

    // Set while a popout is waiting on input it would lose by closing, such as a
    // half-typed passphrase. The grace timer is suspended rather than the popout
    // being pinned, so it still closes on an explicit dismiss.
    property bool hold: false

    function requestHide() {
        if (hold)
            return;
        hideTimer.restart();
    }

    function keepOpen() {
        hideTimer.stop();
    }

    function hide() {
        hideTimer.stop();
        hold = false;
        current = "";
    }

    Timer {
        id: hideTimer

        interval: 180
        onTriggered: root.current = ""
    }
}
