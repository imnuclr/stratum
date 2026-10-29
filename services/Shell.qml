pragma Singleton

import QtQuick
import Quickshell

/*
 * Panel visibility, centralised. Exactly one panel is open at a time; opening
 * another closes the first with a proper cross-transition. Nothing else in the
 * shell may hold its own `visible` state for a panel.
 */
Singleton {
    id: root

    property string openPanel: ""

    function toggle(name) {
        openPanel = openPanel === name ? "" : name;
    }

    function open(name) {
        openPanel = name;
    }

    function close() {
        openPanel = "";
    }
}
