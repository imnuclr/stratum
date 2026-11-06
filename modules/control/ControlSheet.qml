import QtQuick
import Quickshell
import qs.components
import qs.modules.bar.popouts
import qs.config
import qs.services
import qs.theme
import qs.utils

/*
 * The sidebar: what is waiting, and the things you change.
 *
 * These were two panels with two hot corners, and the control centre carried a
 * card whose only job was to count notifications and send you to the other one.
 * That is a strange thing to make someone travel for — the count was right there
 * and acting on it meant going somewhere else — so the list lives here, and the
 * separate page is gone.
 *
 * A full-height column joined to the right edge rather than a card floating in
 * the corner. Two reasons: the notification list wants a fixed tall space rather
 * than a panel that changes shape every time something arrives, and a panel you
 * work down reads as a column. Joined to the edge, with the corners there
 * squared, so it reads as the screen opening rather than a sheet dropped on top
 * of it.
 *
 * Read top to bottom: what has arrived or been written down, then what you can
 * change, then the time and the two things that leave. Notifications and notes
 * share the top as two menus — both are *news*, the reason the panel is being
 * opened most of the time, and the top of a column is where reading starts. The
 * controls sit under them at hand height, and the clock, settings and power sit
 * on the floor of the panel: a footer, not a title. None of them is something
 * you came here to read first, and settings and power in particular are the two
 * that take you out of the panel altogether, so they belong at the end of it
 * rather than above everything else.
 */
Sheet {
    id: root

    name: "control"
    hoverDismiss: true
    adoptOnOpen: false

    // Lives on the right edge, joined to it, and arrives from it.
    originX: 1
    originY: 0
    attached: true
    sideways: true

    sheetWidth: Config.get("control.width", 420)
    sheetHeight: monitor.height

    readonly property real pad: Theme.space(4)

    onOpenChanged: {
        if (open) {
            Media.watch();
            // Ages are relative ("now", "4 min"), so they only tick while
            // someone is actually reading them.
            Notifs.watch();
        } else {
            Media.unwatch();
            Notifs.unwatch();
        }
    }

    /*
     * The networks, devices or focus modes, over the controls that open them.
     *
     * This list used to be a card floating above the panel, outside it, because
     * a panel that grows to fit an expanding section moves its own edges under
     * the pointer: collapsing the section dragged the boundary past the pointer
     * that had just clicked, hover ended, and the whole thing closed. That card
     * was placed by measuring upward from the top of the sheet — which is fine
     * for a sheet with room above it and impossible for this one, a panel that
     * is already as tall as the screen. There was nowhere above it but off the
     * display, and that is where the card went: the chevrons worked, the list
     * drew, and no part of it was ever on screen.
     *
     * Inside the panel instead, laid over the controls and anchored to the same
     * bottom edge they are. The sheet is a fixed size whatever this does, so the
     * reason the card was put outside in the first place does not apply.
     */
    property string lastChip: ""
    property bool listShown: false

    Connections {
        target: Shell

        function onExpandedChipChanged() {
            if (Shell.expandedChip.length > 0) {
                root.lastChip = Shell.expandedChip;
                fold.stop();
                root.listShown = true;
            } else {
                fold.restart();
            }
        }
    }

    /*
     * The list stays in place while it folds away. Its height and its content
     * used to drop to nothing the instant a chip was collapsed, which cut the
     * card off mid-fade: it disappeared instead of closing.
     */
    Timer {
        id: fold

        interval: Theme.sheetMs + 40
        onTriggered: root.listShown = false
    }

    /*
     * Notifications and notes, sharing the room above the controls.
     *
     * Two menus rather than two stacked sections: the top of the panel is the
     * part that should absorb a short screen, and giving each list a tab keeps
     * the controls where they are instead of pushing them up for a block that
     * is not a control.
     */
    SidebarPanel {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: separator.top
        anchors.topMargin: root.pad
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        anchors.bottomMargin: Theme.space(3)
    }

    // The line between what has arrived and what you can change.
    DotRule {
        id: separator

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        anchors.bottom: controls.top
        anchors.bottomMargin: Theme.space(3)
    }

    Column {
        id: controls

        anchors.bottom: footerSeparator.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        anchors.bottomMargin: Theme.space(3)
        spacing: Theme.space(3)

        Row {
            width: parent.width
            spacing: Theme.space(2)

            ServicePill {
                width: (parent.width - Theme.space(2)) / 2
                icon: Network.wiredActive ? "ethernet" : (Wifi.enabled ? "wifi" : "wifi-off")
                title: "Wi-Fi"
                detail: Network.connected ? Network.label : "off"
                active: Wifi.enabled
                open: Shell.expandedChip === "network"
                onToggled: Wifi.setEnabled(!Wifi.enabled)
                onExpanded: Shell.expand("network")
            }

            ServicePill {
                width: (parent.width - Theme.space(2)) / 2
                icon: Bt.enabled ? "bluetooth" : "bluetooth-off"
                title: "Bluetooth"
                detail: Bt.enabled ? Bt.label : "off"
                active: Bt.enabled
                open: Shell.expandedChip === "bluetooth"
                onToggled: Bt.toggle()
                onExpanded: Shell.expand("bluetooth")
            }
        }

        // Focus: the disc turns the last mode used on or off, the chevron
        // opens the list of them over the controls.
        ServicePill {
            width: parent.width
            icon: Focus.current?.icon ?? "moon"
            title: "Focus"
            detail: Focus.on ? `${Focus.current.name} · ${Focus.untilLabel}` : "off"
            active: Focus.on
            open: Shell.expandedChip === "focus"
            onToggled: Focus.toggle()
            onExpanded: Shell.expand("focus")
        }

        QuickToggles {
            width: parent.width
        }

        /*
         * The brightness of the display this panel is on, and only that one.
         *
         * There was a slider per display before, named by model — which answered
         * "they are not linked" but not the question behind it: the control
         * centre is open on one monitor, and that is the one being looked at. A
         * second slider for the other screen is a control for something that is
         * not in front of you. The panel opens on whichever monitor the pointer
         * reached for, so its own screen is the one to offer.
         *
         * Keys remain deliberately different: a brightness key is aimed at
         * nothing in particular, so it moves the whole desk together.
         */
        SliderPill {
            width: parent.width
            icon: "brightness"
            value: Brightness.valueFor(root.monitor.name)
            label: `${Math.round(Brightness.valueFor(root.monitor.name) * 100)}`
            enabled: Brightness.ready
            onMoved: v => Brightness.setForMonitor(root.monitor.name, v)
        }

        SliderPill {
            width: parent.width
            icon: Icons.volume(Audio.volume, Audio.muted)
            value: Audio.muted ? 0 : Audio.volume
            label: `${Math.round(Audio.volume * 100)}`
            onMoved: v => Audio.setVolume(v)
        }

        Rectangle {
            width: parent.width
            height: profiles.height
            radius: height / 2
            color: Theme.surfaceHi
            // A machine with no battery has nothing to trade runtime against, so
            // the control is not worth the room it takes.
            visible: Power.profiles.length > 1 && Power.hasBattery

            SegmentedProfiles {
                id: profiles

                width: parent.width
            }
        }

        MediaCard {
            width: parent.width
            visible: Media.available
        }
    }

    // The same rule again, between the controls and the floor of the panel.
    DotRule {
        id: footerSeparator

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        anchors.bottom: footer.top
        anchors.bottomMargin: Theme.space(3)
    }

    /*
     * The expanded list, over the controls and growing out of the bottom of
     * them. Clipped and capped at the room there is, so a long list of networks
     * cannot reach past the top of the panel and out of the notifications.
     */
    Item {
        id: overlay

        anchors.bottom: controls.bottom
        anchors.left: controls.left
        anchors.right: controls.right
        height: Math.min(listLoader.implicitHeight + root.pad * 2,
            controls.height + Theme.space(3))
        visible: root.listShown

        Rectangle {
            id: listCard

            anchors.fill: parent
            radius: Theme.rSheet
            color: Theme.surface
            border.width: 1
            border.color: Theme.outline
            clip: true
            opacity: Shell.expandedChip.length > 0 ? 1 : 0

            // Unfolds upward out of the control that opened it, and folds back
            // into it.
            transformOrigin: Item.Bottom
            scale: Shell.expandedChip.length > 0 ? 1 : 0.9

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.sheetMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.sheetMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            // Swallows clicks, so a press meant for a row in the list cannot
            // reach the control sitting underneath it.
            MouseArea {
                anchors.fill: parent
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: root.pad
                contentHeight: listLoader.implicitHeight
                clip: true
                interactive: contentHeight > height
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: listLoader

                    width: parent.width
                    active: root.listShown
                    sourceComponent: root.lastChip === "network" ? networkList
                        : (root.lastChip === "focus" ? focusList : deviceList)
                }
            }
        }
    }

    Component {
        id: focusList

        FocusList {}
    }

    Component {
        id: networkList

        NetworkPopout {
            active: true
        }
    }

    Component {
        id: deviceList

        BluetoothPopout {}
    }

    /*
     * The floor of the panel: the time, and the two things that leave it.
     * Settings opens a window and power ends the session — neither is a state,
     * so neither belongs among the toggles, and neither is what the panel is
     * opened to look at, so neither belongs at the top.
     */
    ControlHeader {
        id: footer

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        anchors.bottomMargin: root.pad
    }
}
