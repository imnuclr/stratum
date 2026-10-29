import QtQuick
import Quickshell.Services.Pipewire
import qs.components
import qs.services
import qs.theme

/*
 * Output and input device pickers plus the output level.
 */
Item {
    id: root

    implicitWidth: 286
    implicitHeight: body.implicitHeight

    Column {
        id: body

        width: parent.width
        spacing: Theme.space(2)

        SectionLabel {
            text: "Output device"
        }

        Repeater {
            model: Audio.sinks

            Radio {
                required property PwNode modelData

                width: body.width
                text: Audio.deviceName(modelData)
                checked: Audio.sink?.id === modelData.id
                onClicked: Audio.setSink(modelData)
            }
        }

        SectionLabel {
            topPadding: Theme.space(1)
            text: "Input device"
        }

        Repeater {
            model: Audio.sources

            Radio {
                required property PwNode modelData

                width: body.width
                text: Audio.deviceName(modelData)
                checked: Audio.source?.id === modelData.id
                onClicked: Audio.setSource(modelData)
            }
        }

        Rectangle {
            width: body.width
            height: 1
            color: Theme.line
        }

        Row {
            spacing: Theme.space(2)

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "Volume"
                dim: false
            }

            DotText {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.muted ? "muted" : `${Math.round(Audio.volume * 100)}%`
                size: 13
                color: Audio.muted ? Theme.fgFaint : Theme.fgDim
            }
        }

        LevelSlider {
            width: body.width
            value: Audio.muted ? 0 : Audio.volume
            onMoved: level => Audio.setVolume(level)
        }

        Row {
            width: body.width
            spacing: Theme.space(2)

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: body.width - 34
                text: Audio.sourceMuted ? "Input muted" : "Input live"
                dim: false
            }

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                size: 22
                icon: Audio.sourceMuted ? "mic-off" : "mic"
                active: Audio.sourceMuted
                onClicked: Audio.toggleSourceMuted()
            }
        }

        ActionButton {
            width: body.width
            icon: "settings"
            text: "Open settings"
            visible: Audio.settingsApp.length > 0
            onClicked: Audio.openSettings()
        }
    }
}
