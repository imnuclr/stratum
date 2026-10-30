pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * How bright, how warm, and what is plugged in.
 */
SettingsPage {
    id: page

    icon: "brightness"
    title: "Display"
    detail: "Brightness, night light and the screens connected right now."

    SettingCard {
        title: "brightness"
        footnote: Brightness.displays.length === 0 ? "No display here reports a brightness that can be changed." : ""

        Repeater {
            model: Brightness.displays

            SettingRow {
                id: shade

                required property var modelData

                title: shade.modelData.label === "internal" ? "Built-in display" : shade.modelData.label
                detail: `${Math.round(shade.modelData.value * 100)}%`

                LevelSlider {
                    width: 260
                    count: 26
                    value: shade.modelData.value
                    onMoved: v => Brightness.setFor(shade.modelData.id, v)
                }
            }
        }
    }

    SettingCard {
        title: "colour"

        SettingRow {
            title: "Night light"
            detail: Toggles.hasNight ? "Warmer colours, easier on the eyes after dark." : "Needs hyprsunset or wlsunset installed."

            Switch {
                enabled: Toggles.hasNight
                checked: Toggles.night
                onToggled: Toggles.toggleNight()
            }
        }

        SettingRow {
            title: "Dark mode"
            detail: "The shell and, where they listen, your apps."

            Switch {
                checked: Theme.dark
                onToggled: value => Toggles.setDark(value)
            }
        }
    }

    SettingCard {
        title: "connected displays"
        footnote: "Where each one sits and what bar it shows is under Monitors."

        Repeater {
            model: Quickshell.screens

            SettingRow {
                id: screenRow

                required property ShellScreen modelData

                title: [screenRow.modelData.make, screenRow.modelData.model].filter(s => s && s.length > 0).join(" ") || screenRow.modelData.name
                detail: `${screenRow.modelData.name} · ${screenRow.modelData.width} × ${screenRow.modelData.height} · scale ${Math.round(screenRow.modelData.devicePixelRatio * 100) / 100}`

                LinkButton {
                    text: "arrange"
                    onClicked: Shell.settingsPage = "monitors"
                }
            }
        }
    }
}
