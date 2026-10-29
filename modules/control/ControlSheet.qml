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

    // Notifications are the only unbounded part, so they are what gets capped.
    readonly property int notificationLimit: Config.get("control.notifications", 4)

    name: "control"
    hoverDismiss: true
    originX: 1
    originY: 1
    sheetWidth: Config.get("control.width", 420)
    sheetHeight: Math.min(monitor.height - Theme.space(4) * 4, body.implicitHeight + Theme.space(4) * 2)

    onOpenChanged: {
        if (open) {
            Media.watch();
            Notifs.watch();
        } else {
            Media.unwatch();
            Notifs.unwatch();
        }
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

        SliderPill {
            width: parent.width
            icon: "brightness"
            value: Brightness.value
            label: `${Math.round(Brightness.value * 100)}`
            enabled: Brightness.ready
            onMoved: v => Brightness.set(v)
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
            visible: Power.profiles.length > 1

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

        Repeater {
            model: Notifs.list.slice(0, root.notificationLimit)

            NotificationRow {
                required property var modelData

                width: body.width
                notification: modelData
            }
        }

        SectionLabel {
            dim: true
            text: Notifs.count > root.notificationLimit
                ? `${Notifs.count - root.notificationLimit} more`
                : "nothing to show"
            visible: !Notifs.any || Notifs.count > root.notificationLimit
        }
    }
}
