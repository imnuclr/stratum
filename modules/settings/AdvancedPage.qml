import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * What the shell is doing and where it keeps things, for when something is wrong.
 */
SettingsPage {
    id: page

    icon: "sliders"
    title: "Advanced"
    detail: "Diagnostics and where Stratum keeps its files."

    SettingCard {
        SettingRow {
            width: parent.width
            title: "Diagnostic tracing"
            detail: "Logs hover, panel and popout events. Read it with `stratum trace`. Noisy, so off unless something is misbehaving."

            Switch {
                checked: Config.get("debug.trace", false)
                onToggled: value => Config.set("debug.trace", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Settings folder"
            detail: Theme.dir

            ActionButton {
                text: "open"
                width: 84
                onClicked: Quickshell.execDetached(["xdg-open", Theme.dir])
            }
        }
    }

    SettingCard {
        title: "you"

        SettingRow {
            title: "Your name"
            detail: "How the greeting and lock screen address you."

            TextField {
                width: 200
                height: 30
                placeholder: Account.firstName
                text: Config.get("lock.name", "")
                onAccepted: value => value.trim().length > 0 ? Config.set("lock.name", value.trim()) : Config.unset("lock.name")
            }
        }

        SettingRow {
            title: "Profile picture"
            detail: Account.avatar.length > 0 ? Account.avatar : "None found. ~/.face is used when there is one."

            Row {
                spacing: Theme.space(2)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: Theme.surfaceTop
                    clip: true

                    Image {
                        anchors.fill: parent
                        visible: Account.avatar.length > 0
                        source: Account.avatar.length > 0 ? `file://${Account.avatar}` : ""
                        sourceSize.width: 72
                        sourceSize.height: 72
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                LinkButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "choose"
                    onClicked: Picker.file("Profile picture", true, path => Config.set("lock.avatar", path))
                }

                LinkButton {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Config.get("lock.avatar", "").length > 0
                    text: "reset"
                    onClicked: Config.unset("lock.avatar")
                }
            }
        }
    }
}
