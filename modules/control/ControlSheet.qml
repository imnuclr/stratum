import QtQuick
import Quickshell
import qs.components
import qs.modules.bar.popouts
import qs.config
import qs.services
import qs.theme
import qs.utils

/*
 * The control centre: the things you change. The dashboard is the counterpart —
 * that one is what you read.
 *
 * Grows out of the bottom-right corner, which is where it is reached from.
 */
Sheet {
    id: root

    name: "control"
    hoverDismiss: true
    originX: 1
    originY: 1
    sheetWidth: Config.get("control.width", 420)
    // Clamped to the room actually available, not to a guess at it.
    sheetHeight: Math.min(availableHeight, body.implicitHeight + Theme.space(4) * 2)

    /*
     * Media only: no notification ages are shown here any more, so nothing on
     * this panel needs a ticking clock. Shell collapses whichever list was open
     * when a panel closes, so the height is its own business on the next open.
     */
    onOpenChanged: {
        if (open) {
            Media.watch();
        } else {
            Media.unwatch();
        }
    }

    /*
     * The networks or devices, in a card of their own above the panel.
     *
     * Reaching for a network used to close the control centre and put the list in
     * a bar popout at the other end of the screen, which is a strange thing to do
     * to someone who has just said they want to pick one: the thing they clicked
     * disappears. Putting the list inside the panel instead made the panel grow
     * and shrink, and collapsing it dragged the panel's own edge past the pointer
     * that had just clicked — so it closed. Above the panel, the panel never
     * moves.
     */
    /*
     * The list stays in place while it folds away. Its height and its content
     * used to drop to nothing the instant a chip was collapsed, which cut the
     * card off mid-fade: it disappeared instead of closing.
     */
    property string lastChip: ""
    property bool satelliteShown: false

    Connections {
        target: Shell

        function onExpandedChipChanged() {
            if (Shell.expandedChip.length > 0) {
                root.lastChip = Shell.expandedChip;
                fold.stop();
                root.satelliteShown = true;
            } else {
                fold.restart();
            }
        }
    }

    Timer {
        id: fold

        interval: Theme.sheetMs + 40
        onTriggered: root.satelliteShown = false
    }

    satelliteHeight: root.satelliteShown ? Math.round(listLoader.implicitHeight + Theme.space(4) * 2) : 0

    satellite: Rectangle {
        id: listCard

        anchors.fill: parent
        radius: Theme.rSheet
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
        opacity: Shell.expandedChip.length > 0 ? 1 : 0

        /*
         * Grows out of the chip rather than appearing over it: anchored to the
         * bottom edge it shares with the panel, so it unfolds upward from the
         * control that opened it and folds back into it.
         */
        transformOrigin: Item.Bottom
        scale: Shell.expandedChip.length > 0 ? 1 : 0.82

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

        Loader {
            id: listLoader

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.space(4)
            active: root.satelliteShown
            sourceComponent: root.lastChip === "network" ? networkList : deviceList
        }
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

    Column {
        id: body

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.space(4)
        spacing: Theme.space(3)

        ControlHeader {
            width: parent.width
        }

        Row {
            width: parent.width
            spacing: Theme.space(2)

            ServicePill {
                width: (parent.width - Theme.space(2)) / 2
                icon: Network.wiredActive ? "ethernet" : (Wifi.enabled ? "wifi" : "wifi-off")
                title: "Wi-Fi"
                detail: Network.connected ? Network.label : "off"
                active: Wifi.enabled
                onToggled: Wifi.setEnabled(!Wifi.enabled)
                onExpanded: Shell.expand("network")
            }

            ServicePill {
                width: (parent.width - Theme.space(2)) / 2
                icon: Bt.enabled ? "bluetooth" : "bluetooth-off"
                title: "Bluetooth"
                detail: Bt.enabled ? Bt.label : "off"
                active: Bt.enabled
                onToggled: Bt.toggle()
                onExpanded: Shell.expand("bluetooth")
            }
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

        /*
         * Only how many, and clearly. The notifications themselves live on their
         * own page: an unbounded list at the bottom of a fixed panel was always
         * the part that got cut, and a panel you open to change a setting is not
         * where you want to be reading. This is the way across.
         */
        Rectangle {
            width: parent.width
            height: 56
            radius: height / 2
            color: Notifs.any && countHover.hovered ? Theme.surfaceTop : Theme.surfaceHi

            Behavior on color {
                ColorAnimation {
                    duration: Theme.micro
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.space(4)
                spacing: Theme.space(3)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Notifs.any ? "bell" : "bell-off"
                    size: 20
                    color: Notifs.any ? Theme.fg : Theme.fgDim
                }

                DotText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.any
                    text: `${Notifs.count}`
                    size: 24
                    plain: true
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: !Notifs.any ? "No notifications" : (Notifs.count === 1 ? "notification" : "notifications")
                    color: Notifs.any ? Theme.fg : Theme.fgBright
                    font.family: Theme.fontUi
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Theme.space(4)
                name: "chevron-left"
                size: 16
                rotation: 180
                color: Theme.fgBright
                visible: Notifs.any
            }

            HoverHandler {
                id: countHover

                cursorShape: Notifs.any ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                enabled: Notifs.any
                onTapped: Shell.open("notifications", root.monitor.name)
            }
        }
    }
}
