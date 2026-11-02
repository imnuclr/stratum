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
            detail: "The Do Not Disturb focus: nothing appears on screen. Notifications still collect in the page."

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

    /*
     * Focus modes: what each lets through, and whether the control centre
     * offers it. The app lists are comma-separated, matched against the
     * sender's name, and saved when the field is left or Enter is pressed.
     */
    SettingCard {
        title: "focus"
        footnote: "Silenced notifications still collect in the page. Switch a mode off to hide it from the control centre."

        Repeater {
            model: Focus.modes

            SettingRow {
                id: modeRow

                required property var modelData

                width: parent.width
                title: modeRow.modelData.name
                detail: Focus.allowed(modeRow.modelData.id).length > 0
                    ? "Lets these apps through."
                    : "Lets nothing through. Add apps to let them in."

                Row {
                    spacing: Theme.space(3)

                    TextField {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        text: Focus.allowed(modeRow.modelData.id).join(", ")
                        placeholder: "apps, comma separated"
                        onFinished: value => Focus.setAllowed(modeRow.modelData.id, value)
                    }

                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: !Focus.hidden.includes(modeRow.modelData.id)
                        onToggled: value => Focus.setShown(modeRow.modelData.id, value)
                    }
                }
            }
        }

        SettingRow {
            width: parent.width
            title: "Sleep warms the screen"
            detail: "Turns the night light on with Sleep, and off again after."
            visible: Toggles.hasNight

            Switch {
                checked: Focus.sleepWarms
                onToggled: value => Config.set("focus.sleepNight", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Gaming turns on game mode"
            detail: "Performance profile, no animations, and the machine kept awake."

            Switch {
                checked: Focus.gamingGameMode
                onToggled: value => Config.set("focus.gamingGameMode", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Critical breaks through"
            detail: "Urgent notifications, like a battery about to run out, show whatever the mode."

            Switch {
                checked: Focus.criticalThrough
                onToggled: value => Config.set("focus.critical", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Morning"
            detail: "When \"until morning\" ends."

            Stepper {
                value: Focus.morningHour
                from: 4
                to: 12
                step: 1
                suffix: ":00"
                onMoved: v => Config.set("focus.morning", v)
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
                value: Math.round(Config.get("screenshot.offerMs", 2000) / 1000)
                from: 1
                to: 60
                step: 1
                suffix: "s"
                onMoved: v => Config.set("screenshot.offerMs", v * 1000)
            }
        }
    }
}
