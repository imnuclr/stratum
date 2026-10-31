import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * How notifications announce themselves.
 */
SettingsPage {
    id: page

    icon: "bell"
    title: "Notifications"
    detail: "How notifications announce themselves, and for how long."

    readonly property real minSeconds: 2
    readonly property real maxSeconds: 15
    readonly property real toastSeconds: Config.get("notifications.toastMs", 5000) / 1000

    SettingCard {
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

    // The bar that offers a fresh screenshot, which is a passing on-screen
    // message like the rest of this page.
    SettingCard {
        title: "screenshots"
        footnote: `Saved ones go to ${Screenshot.directory.replace(Quickshell.env("HOME"), "~")}.`

        SettingRow {
            title: "Ask before saving"
            detail: "A bar at the foot of the screen offers to save or edit. Off saves every screenshot straight away."

            Switch {
                checked: !Config.get("screenshot.autoSave", false)
                onToggled: value => Config.set("screenshot.autoSave", !value)
            }
        }

        SettingRow {
            visible: !Config.get("screenshot.autoSave", false)
            title: "How long it waits"
            detail: "Pointing at the bar stops the clock."

            Stepper {
                value: Math.round(Config.get("screenshot.offerMs", 9000) / 1000)
                from: 3
                to: 60
                step: 1
                suffix: "s"
                onMoved: v => Config.set("screenshot.offerMs", v * 1000)
            }
        }
    }
}
