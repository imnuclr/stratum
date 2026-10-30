pragma Singleton

import QtQuick
import Quickshell
import qs.services

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
     * Settings is a window, not a panel, so it has its own state: opening the
     * control centre or a menu over it must not close it, the way one panel
     * replaces another. Asking for "settings" through open or toggle lands here.
     */
    property bool settingsOpen: false

    // Whether the settings window is on the workspace in front of you.
    function settingsHere() {
        const win = Hypr.toplevels.find(t => t.title === "Stratum Settings");
        return !win || win.workspace?.id === Hypr.focusedWorkspace?.id;
    }

    function closeSettings() {
        root.settingsOpen = false;
    }

    /*
     * Which screen the open panel belongs to. Panels are built per screen, so
     * without this every screen's copy shows at once and the panel appears on
     * both monitors. Empty means "wherever", for a panel opened over IPC with no
     * pointer to attribute it to.
     */
    property string openScreen: ""

    // Where the open panel was asked for from — "bar", "control" or empty — so a
    // panel reachable from more than one place can open beside whichever it was.
    property string openFrom: ""

    // Set when a panel was opened by hover, so a click-opened panel is not
    // dismissed by the pointer wandering off.
    /*
     * Whether hover-out should close the panel that is open.
     *
     * Set when a hot zone opened it, and also the first time the pointer lands on
     * a panel opened any other way — a sheet reached from a keybind or from
     * another panel's link should not vanish because the pointer is elsewhere,
     * but once it has been used with the pointer, leaving it should close it like
     * anything else. Without the second half, the notification page opened from
     * the control centre's link stayed up no matter where the pointer went.
     */
    property bool hoverOpened: false

    /*
     * Which service chip has its list open inside the control centre, if any.
     * Kept here rather than on the sheet because there is one control centre per
     * monitor and only one of them is ever the open one — state on the sheet
     * belonged to whichever instance happened to hold it.
     */
    property string expandedChip: ""

    // Which settings page is showing. Here rather than on the sheet because there
    // is one sheet per monitor and the choice should follow you between them.
    property string settingsPage: "wallpaper"

    // A setting to bring into view and flash once its page is showing, by its
    // title. Cleared by the row that answers to it.
    property string settingsFocus: ""

    function expand(which) {
        root.expandedChip = root.expandedChip === which ? "" : which;
    }

    function engage() {
        root.hoverOpened = true;
        adopt.stop();
    }

    /*
     * A panel that dismisses on hover but was not opened by it — reached from a
     * keybind, or from another panel's link — takes a moment to adopt the rule,
     * so there is time to move onto it. After that, being away from it closes
     * it like anything else. Without this, the notification page opened from the
     * control centre's link had nothing to arm it: the pointer was at the far
     * corner and never touched the page, so it stayed up for good.
     */
    function armDismiss() {
        if (root.hoverOpened)
            return;
        adopt.restart();
    }
    property int holds: 0

    function toggle(name, screen, from) {
        if (name === "settings") {
            /*
             * Open, but on another workspace: asking for it brings it here
             * rather than closing it. Closing first meant a second click to
             * get it back, on the workspace you had just left.
             */
            if (root.settingsOpen && !root.settingsHere()) {
                Hypr.bringWindow("title:^(Stratum Settings)$");
                root.close();
                return;
            }
            root.settingsOpen = !root.settingsOpen;
            if (root.settingsOpen)
                root.close();
            return;
        }
        // A click on the trigger that opened a click-dismissed panel first lands
        // outside it, closing it, and then arrives here as a toggle. Without this
        // the panel closed and immediately opened again.
        if (cooldown.running && name === root.lastClosed && openPanel.length === 0)
            return;
        root.openFrom = from ?? "";
        root.hoverOpened = false;
        root.expandedChip = "";
        adopt.stop();
        root.openScreen = screen ?? "";
        openPanel = openPanel === name ? "" : name;
    }

    function open(name, screen) {
        if (name === "settings") {
            if (root.settingsOpen && !root.settingsHere())
                Hypr.bringWindow("title:^(Stratum Settings)$");
            root.settingsOpen = true;
            root.close();
            return;
        }
        root.hoverOpened = false;
        root.expandedChip = "";
        adopt.stop();
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

    /*
     * Where a pointerless open lands — a keybind or an IPC call, with no pointer
     * to attribute it to. The focused monitor, because that is where the person
     * is working; the widest only as a fallback before Hyprland has reported one.
     */
    readonly property string fallbackScreen: {
        const focused = Hypr.focusedWorkspace?.monitor?.name ?? "";
        if (focused.length > 0)
            return focused;
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
        root.expandedChip = "";
        adopt.stop();
        if (openPanel.length > 0) {
            root.lastClosed = openPanel;
            cooldown.restart();
        }
        openPanel = "";
        root.openScreen = "";
    }

    function hold() {
        root.holds++;
        Diag.log("shell", `hold -> ${root.holds} (${root.openPanel})`);
        grace.stop();
    }

    function release() {
        root.holds = Math.max(0, root.holds - 1);
        Diag.log("shell", `release -> ${root.holds} (${root.openPanel})`);
        if (root.holds === 0 && root.hoverOpened)
            grace.restart();
    }

    Timer {
        id: cooldown

        interval: 400
    }

    Timer {
        id: adopt

        interval: 1500
        onTriggered: {
            root.hoverOpened = true;
            if (root.holds === 0 && root.openPanel.length > 0) {
                Diag.log("shell", `nothing holding ${root.openPanel}, closing`);
                root.close();
            }
        }
    }

    Timer {
        id: grace

        /*
         * Barely there. Leaving a panel should close it, not begin closing it.
         * All this still covers is the single frame where a hot zone has handed
         * the pointer to the sheet it opened and the sheet has not yet said so,
         * and the window in which a grab that cleared hover can be caught out.
         */
        interval: 90
        onTriggered: {
            if (root.holds === 0 && root.hoverOpened) {
                Diag.log("shell", `grace elapsed, closing ${root.openPanel}`);
                root.close();
            }
        }
    }
}
