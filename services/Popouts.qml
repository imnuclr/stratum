pragma Singleton

import QtQuick
import Quickshell
import qs.services

/*
 * Hover popouts for bar items.
 *
 * Separate from Shell.openPanel on purpose: popouts are transient and
 * hover-driven, they never grab keyboard focus, and one may replace another
 * without closing first — which is what lets the container morph between them
 * instead of blinking.
 *
 * Whether to close is decided from hover *state*, never from the last enter or
 * leave event received. Two things make event-driven logic wrong here:
 *
 *  - Qt may deliver the new item's enter before the old item's leave, so acting
 *    on the most recent leave closes the popout that was just opened.
 *  - A child MouseArea with hoverEnabled takes hover from its parent and fires
 *    the parent's onExited, so every control inside a panel reads as leaving it.
 *
 * The panel therefore reports a continuously bound `surfaceHovered` from a
 * HoverHandler, which stays true while the pointer is over a child, and triggers
 * report which one of them is hovered rather than that one was left.
 */
Singleton {
    id: root

    property string current: ""
    property string monitorName: ""
    // Centre of the hovered item, in bar-window coordinates.
    property real anchorX: 0
    property real anchorY: 0

    readonly property bool open: current.length > 0

    // The tray item a "tray:…" popout is about.
    property var trayItem: null

    // Initialised from current rather than empty: the handler below only fires on
    // a change, so a popout already open across a config reload would render an
    // empty frame. The first assignment replaces this binding.
    property string content: current

    // Set while a popout is waiting on input it would lose by closing, such as a
    // half-typed passphrase. The grace timer is suspended rather than the popout
    // being pinned, so it still closes on an explicit dismiss.
    property bool hold: false

    // Bound by the panel from a HoverHandler, so it stays true over its controls.
    property bool surfaceHovered: false
    // The trigger the pointer is currently inside, if any.
    property string hoveredTrigger: ""

    /*
     * True while the pointer is anywhere in the group of triggers, including the
     * gaps between them. Each icon claims `hoveredTrigger` for itself, so pausing
     * between two of them left nothing holding the popout open and it closed
     * under a pointer that was on its way to the next icon.
     */
    property bool groupHovered: false

    readonly property bool anyHover: surfaceHovered || groupHovered || hoveredTrigger.length > 0

    onCurrentChanged: {
        if (current.length > 0)
            content = current;
    }

    onAnyHoverChanged: root.settle()

    onGroupHoveredChanged: root.settle()

    onHoldChanged: root.settle()

    function settle() {
        if (anyHover || hold)
            hideTimer.stop();
        else
            hideTimer.restart();
    }

    // A trigger was entered.
    /*
     * The vertical bar anchors its popouts level with the trigger, so it hands
     * over a y. Kept as a separate property rather than one orientation-agnostic
     * "anchor" so each surface reads only the axis it actually positions on.
     */
    function showAtY(name, y, monitor) {
        hideTimer.stop();
        hoveredTrigger = name;
        current = name;
        anchorY = y;
        monitorName = monitor;
    }

    function show(name, x, monitor) {
        hideTimer.stop();
        hoveredTrigger = name;
        current = name;
        anchorX = x;
        monitorName = monitor;
    }

    /*
     * A trigger was left. Ignored unless it is still the hovered one: when the
     * pointer moves straight to the next trigger, that one has already claimed
     * `hoveredTrigger` and this leave is stale.
     */
    function release(name) {
        if (hoveredTrigger === name)
            hoveredTrigger = "";
    }

    function hide() {
        hideTimer.stop();
        hold = false;
        surfaceHovered = false;
        hoveredTrigger = "";
        current = "";
    }

    // Long enough to cross the gap between a bar item and the panel below it.
    Timer {
        id: hideTimer

        // Long enough only to cross between two triggers that sit apart, which
        // the group hover already covers; anything more reads as the popout
        // refusing to leave.
        interval: 70
        // Re-checked rather than trusted: the timer may have been started before
        // the pointer landed somewhere that holds the popout open.
        onTriggered: {
            if (!root.anyHover && !root.hold)
                root.hide();
        }
    }
}
