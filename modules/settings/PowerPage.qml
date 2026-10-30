pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The battery, how hard the machine works, and whether it may sleep.
 */
SettingsPage {
    id: page

    icon: "bolt"
    title: "Power"
    detail: "Battery, power profile and keeping the screen awake."

    // How much is left, as large as the lock screen would draw it.
    Rectangle {
        visible: Power.hasBattery
        height: 132
        radius: Theme.rTile
        color: Theme.surfaceHi
        border.width: 1
        border.color: Theme.line

        BatteryGlyph {
            id: cell

            anchors.left: parent.left
            anchors.leftMargin: Theme.space(6)
            anchors.verticalCenter: parent.verticalCenter
            size: 72
            level: Power.percentage
            charging: Power.charging
            color: Power.low ? Theme.crit : Theme.fg
        }

        Column {
            anchors.left: cell.right
            anchors.leftMargin: Theme.space(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(1)

            DotText {
                text: `${Math.round(Power.percentage * 100)}%`
                size: 34
            }

            Text {
                text: Power.full ? "Fully charged"
                    : Power.charging ? (Power.timeToFull > 0 ? `Charging · full in ${Power.formatTime(Power.timeToFull)}` : "Charging")
                    : Power.onBattery ? (Power.timeToEmpty > 0 ? `On battery · ${Power.formatTime(Power.timeToEmpty)} left` : "On battery")
                    : "Plugged in"
                color: Theme.fgDim
                font.family: Theme.fontUi
                font.pixelSize: 13
                renderType: Text.NativeRendering
            }
        }
    }

    SettingCard {
        title: "performance"

        SettingRow {
            title: "Power profile"
            detail: Power.profile === "power-saver" ? "Longest battery life; things may feel a touch slower."
                : Power.profile === "performance" ? "Everything as fast as it goes, at the battery's expense."
                : "A balance of speed and battery life."

            Segmented {
                readonly property var names: ({ "power-saver": "eco", "balanced": "balanced", "performance": "performance" })

                model: Power.profiles.map(p => names[p])
                current: Math.max(0, Power.profiles.indexOf(Power.profile))
                onPicked: index => Power.setProfile(Power.profiles[index])
            }
        }

        SettingRow {
            visible: Power.hasBattery
            title: "Lower refresh rate in eco"
            detail: "Drops the built-in screen to its slowest refresh rate while eco is on, and puts it back after."

            Switch {
                checked: Config.get("power.ecoRefresh", true)
                onToggled: value => Config.set("power.ecoRefresh", value)
            }
        }
    }

    SettingCard {
        title: "sleep"

        SettingRow {
            title: "Keep awake"
            detail: "Stops the screen dimming, locking or sleeping on its own until you turn this off."

            Switch {
                checked: Toggles.caffeine
                onToggled: Toggles.toggleCaffeine()
            }
        }
    }
}
