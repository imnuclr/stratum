import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * How notifications announce themselves.
 */
Item {
    id: page

    readonly property real minSeconds: 2
    readonly property real maxSeconds: 15
    readonly property real toastSeconds: Config.get("notifications.toastMs", 5000) / 1000

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SectionLabel {
            text: "notifications"
            bottomPadding: Theme.space(3)
        }

        SettingRow {
            width: parent.width
            title: "Do not disturb"
            detail: "Nothing appears on screen. Notifications still collect in the page."

            Switch {
                checked: Notifs.dnd
                onToggled: Notifs.toggleDnd()
            }
        }

        SettingRow {
            width: parent.width
            implicitHeight: 96
            title: "Toast duration"
            detail: "How long one stays up. Hovering holds it; urgent ones stay until dismissed."

            SliderPill {
                width: 240
                icon: "bell"
                value: (page.toastSeconds - page.minSeconds) / (page.maxSeconds - page.minSeconds)
                label: `${Math.round(page.toastSeconds)}s`
                onMoved: v => Config.set("notifications.toastMs",
                    Math.round((page.minSeconds + v * (page.maxSeconds - page.minSeconds)) * 1000 / 500) * 500)
            }
        }

        SettingRow {
            width: parent.width
            title: "Try it"
            detail: "Sends a test notification, to see how the current settings look."

            ActionButton {
                text: "send test"
                width: 108
                onClicked: Quickshell.execDetached(["notify-send", "-a", "Stratum", "Settings", "This is what a notification looks like."])
            }
        }

        SettingRow {
            width: parent.width
            title: "Clear everything"
            detail: `${Notifs.count} in the page right now.`

            ActionButton {
                text: "clear all"
                width: 108
                enabled: Notifs.any
                onClicked: Notifs.clearAll()
            }
        }
    }
}
