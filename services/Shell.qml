pragma Singleton

import QtQuick
import Quickshell

/*
 * Panel visibility, centralised. Exactly one panel is open at a time; opening
 * another closes the first with a proper cross-transition. Nothing else in the
 * shell may hold its own `visible` state for a panel.
 *
 * Panels opened by hover are counted rather than toggled. The trigger on the bar
 * and the panel itself are separate surfaces with a gap between them, so either
 * one being hovered has to keep the panel alive while the pointer crosses — and
 * the pointer can leave the trigger before it reaches the panel. Counting holds
 * means neither side has to know about the other.
 */
Singleton {
    id: root

    property string openPanel: ""

    // Set when a panel was opened by hover, so a click-opened panel is not
    // dismissed by the pointer wandering off.
    property bool hoverOpened: false
    property int holds: 0

    function toggle(name) {
        root.hoverOpened = false;
        openPanel = openPanel === name ? "" : name;
    }

    function open(name) {
        root.hoverOpened = false;
        openPanel = name;
    }

    function openOnHover(name) {
        grace.stop();
        root.hoverOpened = true;
        openPanel = name;
    }

    function close() {
        grace.stop();
        root.holds = 0;
        root.hoverOpened = false;
        openPanel = "";
    }

    function hold() {
        root.holds++;
        grace.stop();
    }

    function release() {
        root.holds = Math.max(0, root.holds - 1);
        if (root.holds === 0 && root.hoverOpened)
            grace.restart();
    }

    Timer {
        id: grace

        // Long enough to cross the gap between a bar item and the panel it
        // opened, short enough that leaving on purpose feels immediate.
        interval: 260
        onTriggered: {
            if (root.holds === 0 && root.hoverOpened)
                root.close();
        }
    }
}
