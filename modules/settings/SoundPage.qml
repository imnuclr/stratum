pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * What you hear and what hears you: levels, mutes, and which device each goes
 * through.
 */
SettingsPage {
    id: page

    icon: "volume-2"
    title: "Sound"
    detail: "Output and input levels, and the devices they use."

    SettingCard {
        title: "output"

        SettingRow {
            title: "Volume"
            detail: Audio.muted ? "muted" : `${Math.round(Audio.volume * 100)}%`

            LevelSlider {
                width: 260
                count: 26
                value: Audio.volume
                enabled: !Audio.muted
                onMoved: v => Audio.setVolume(v)
            }
        }

        SettingRow {
            title: "Mute"

            Switch {
                checked: Audio.muted
                onToggled: value => Audio.setMuted(value)
            }
        }

        SettingRow {
            title: "Step"
            detail: "How far the volume keys move it each press."

            Stepper {
                value: Config.get("audio.step", 2)
                from: 1
                to: 10
                step: 1
                suffix: "%"
                onMoved: v => Config.set("audio.step", v)
            }
        }

        SettingRow {
            title: "Show the level when it changes"
            detail: "The little overlay that appears on the volume and brightness keys."

            Switch {
                checked: Config.get("osd.enabled", true)
                onToggled: value => Config.set("osd.enabled", value)
            }
        }

        SettingRow {
            visible: Config.get("osd.enabled", true)
            title: "On every screen"
            detail: "Off shows it only on the screen you are using."

            Switch {
                checked: Config.get("osd.everywhere", true)
                onToggled: value => Config.set("osd.everywhere", value)
            }
        }
    }

    SettingCard {
        title: "play sound through"

        Repeater {
            model: Audio.sinks

            ChoiceRow {
                required property var modelData

                icon: /head|blue|bt/i.test(Audio.deviceName(modelData)) ? "headphones" : "volume-2"
                title: Audio.deviceName(modelData)
                sub: modelData === Audio.sink ? "in use" : ""
                chosen: modelData === Audio.sink
                onClicked: Audio.setSink(modelData)
            }
        }
    }

    SettingCard {
        title: "input"

        SettingRow {
            title: "Microphone level"
            detail: Audio.sourceMuted ? "muted" : `${Math.round(Audio.sourceVolume * 100)}%`

            LevelSlider {
                width: 260
                count: 26
                value: Audio.sourceVolume
                enabled: !Audio.sourceMuted
                onMoved: v => Audio.setSourceVolume(v)
            }
        }

        SettingRow {
            title: "Mute the microphone"

            Switch {
                checked: Audio.sourceMuted
                onToggled: Audio.toggleSourceMuted()
            }
        }
    }

    SettingCard {
        title: "listen through"

        Repeater {
            model: Audio.sources

            ChoiceRow {
                required property var modelData

                icon: "mic"
                title: Audio.deviceName(modelData)
                sub: modelData === Audio.source ? "in use" : ""
                chosen: modelData === Audio.source
                onClicked: Audio.setSource(modelData)
            }
        }
    }

    SettingCard {
        visible: Audio.settingsApp.length > 0

        SettingRow {
            title: "Per-app volume and more"
            detail: `In ${Audio.settingsApp}.`

            LinkButton {
                text: "open"
                onClicked: Audio.openSettings()
            }
        }
    }
}
