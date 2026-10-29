import QtQuick
import Quickshell
import qs.components
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

    // Media only: no notification ages are shown here any more, so nothing on
    // this panel needs a ticking clock.
    onOpenChanged: open ? Media.watch() : Media.unwatch()

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
                onExpanded: Shell.close()
            }

            ServicePill {
                width: (parent.width - Theme.space(2)) / 2
                icon: Bt.enabled ? "bluetooth" : "bluetooth-off"
                title: "Bluetooth"
                detail: Bt.enabled ? Bt.label : "off"
                active: Bt.enabled
                onToggled: Bt.toggle()
                onExpanded: Shell.close()
            }
        }

        QuickToggles {
            width: parent.width
        }

        /*
         * One slider per display, named, because two monitors do not agree about
         * what looks right — and a single slider moving both meant setting the
         * dimmer one correctly always overexposed the other. A single-display
         * machine gets exactly one and looks no different to before.
         */
        Repeater {
            model: Brightness.displays

            Column {
                id: dim

                required property var modelData

                width: parent.width
                spacing: Theme.space(1)

                // Only worth naming when there is more than one to tell apart.
                SectionLabel {
                    text: dim.modelData.label
                    visible: Brightness.displays.length > 1
                }

                SliderPill {
                    width: parent.width
                    icon: "brightness"
                    value: dim.modelData.value
                    label: `${Math.round(dim.modelData.value * 100)}`
                    enabled: Brightness.ready
                    onMoved: v => Brightness.setFor(dim.modelData.id, v)
                }
            }
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

        Item {
            width: parent.width
            height: header.implicitHeight + Theme.space(1)

            SectionLabel {
                id: header

                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: Notifs.any ? `notifications · ${Notifs.count}` : "notifications"
            }

            SectionLabel {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: "clear all"
                color: clearHover.hovered ? Theme.fg : Theme.fgBright
                visible: Notifs.any

                HoverHandler {
                    id: clearHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Notifs.clearAll()
                }
            }
        }

        /*
         * The notifications themselves live on their own page. An unbounded list
         * at the bottom of a fixed panel was always the part that got cut, and a
         * panel you open to change a setting is not where you want to be reading.
         * This is the way across.
         */
        SectionLabel {
            dim: !Notifs.any
            text: Notifs.any ? "open page" : "nothing to show"
            color: Notifs.any && openHover.hovered ? Theme.fg : (Notifs.any ? Theme.fgDim : Theme.fgFaint)

            HoverHandler {
                id: openHover

                cursorShape: Notifs.any ? Qt.PointingHandCursor : Qt.ArrowCursor
            }

            TapHandler {
                enabled: Notifs.any
                onTapped: Shell.open("notifications", root.monitor.name)
            }
        }
    }
}
