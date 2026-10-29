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

    /*
     * Which screen the open panel belongs to. Panels are built per screen, so
     * without this every screen's copy shows at once and the panel appears on
     * both monitors. Empty means "wherever", for a panel opened over IPC with no
     * pointer to attribute it to.
     */
    property string openScreen: ""

    // Set when a panel was opened by hover, so a click-opened panel is not
    // dismissed by the pointer wandering off.
    property bool hoverOpened: false
    property int holds: 0

    function toggle(name, screen) {
        root.hoverOpened = false;
        root.openScreen = screen ?? "";
        openPanel = openPanel === name ? "" : name;
    }

    function open(name, screen) {
        root.hoverOpened = false;
        root.openScreen = screen ?? "";
        openPanel = name;
    }

    function openOnHover(name, screen) {
        // A panel that has only just been dismissed is not reopened by the same
        // pointer still sitting in the zone that opened it. Without this the
        // panel closing under the pointer frees the zone to fire again and the
        // two take turns forever.
        if (cooldown.running && name === root.lastClosed)
            return;
        grace.stop();
        root.hoverOpened = true;
        root.openScreen = screen ?? "";
        openPanel = name;
    }

    // Where a pointerless open lands: the bar's screen if one is configured,
    // otherwise the widest, which on a mixed setup is the one being worked on.
    readonly property string fallbackScreen: {
        const screens = Quickshell.screens;
        if (screens.length === 0)
            return "";
        let best = screens[0];
        for (const s of screens)
            if (s.width > best.width)
                best = s;
        return best.name;
    }

    property string lastClosed: ""

    function close() {
        grace.stop();
        root.holds = 0;
        root.hoverOpened = false;
        if (openPanel.length > 0) {
            root.lastClosed = openPanel;
            cooldown.restart();
        }
        openPanel = "";
        root.openScreen = "";
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
        id: cooldown

        interval: 400
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
