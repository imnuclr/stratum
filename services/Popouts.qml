pragma Singleton

import QtQuick
import Quickshell

/*
 * Hover popouts for bar items.
 *
 * Separate from Shell.openPanel on purpose: popouts are transient and
 * hover-driven, they never grab keyboard focus, and one may replace another
 * without closing first — which is what lets the container slide and resize
 * between them instead of blinking.
 *
 * Closing is decided by how many hover sources are active rather than by the last
 * event received. Qt can deliver the new item's enter before the old item's
 * leave, so a close request from whichever element was left most recently would
 * cancel the popout that had just opened — the menu appeared and immediately
 * shut. Counting sources makes the outcome independent of delivery order, and
 * covers the popout body as a source too, so travelling from a bar item into the
 * panel and back out to a different item never drops the popout.
 */
Singleton {
    id: root

    property string current: ""
    property string monitorName: ""
    // Centre of the hovered item, in bar-window coordinates.
    property real anchorX: 0

    readonly property bool open: current.length > 0

    // Initialised from current rather than empty: the handler below only fires on
    // a change, so a popout already open across a config reload would render an
    // empty frame. The first assignment replaces this binding.
    property string content: current

    // Set while a popout is waiting on input it would lose by closing, such as a
    // half-typed passphrase. The grace timer is suspended rather than the popout
    // being pinned, so it still closes on an explicit dismiss.
    property bool hold: false

    // Names of everything the pointer is currently inside: trigger items by their
    // popout name, and the panel body as "surface".
    property var sources: ({})

    onCurrentChanged: {
        if (current.length > 0)
            content = current;
    }

    // Releasing the hold after the pointer has already left would otherwise leave
    // the popout up with nothing to close it.
    onHoldChanged: {
        if (!hold && Object.keys(sources).length === 0)
            hideTimer.restart();
    }

    // A trigger was entered: show its popout and register it as a hover source.
    function show(name, x, monitor) {
        hideTimer.stop();
        sources[name] = true;
        sources = sources;
        current = name;
        anchorX = x;
        monitorName = monitor;
    }

    // The panel body was entered. It holds the popout open without changing which
    // popout is shown.
    function enterSurface() {
        hideTimer.stop();
        sources.surface = true;
        sources = sources;
    }

    function leaveSurface() {
        root.release("surface");
    }

    // Something was left. Only the last source leaving starts the countdown.
    function release(name) {
        delete sources[name];
        sources = sources;

        if (hold)
            return;
        if (Object.keys(sources).length === 0)
            hideTimer.restart();
    }

    function hide() {
        hideTimer.stop();
        hold = false;
        sources = ({});
        current = "";
    }

    // Long enough to cross the gap between a bar item and the panel below it.
    Timer {
        id: hideTimer

        interval: 180
        onTriggered: root.hide()
    }
}
