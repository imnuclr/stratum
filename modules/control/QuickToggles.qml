import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The eight quick toggles, four to a row.
 *
 * Each names the service that owns its state rather than holding any itself, so
 * the bar's indicators and these stay in step without either knowing about the
 * other.
 */
Column {
    id: root

    readonly property real cell: width / 4

    spacing: Theme.space(3)

    Repeater {
        model: [
            [
                { icon: "bell-off", label: "dnd", active: Notifs.dnd, available: true, act: () => Notifs.toggleDnd() },
                { icon: "moon", label: "night", active: Toggles.night, available: Toggles.hasNight, act: () => Toggles.toggleNight() },
                { icon: "airplane", label: "airplane", active: Toggles.airplane, available: true, act: () => Toggles.toggleAirplane() },
                { icon: "coffee", label: "caffeine", active: Toggles.caffeine, available: true, act: () => Toggles.toggleCaffeine() }
            ],
            [
                { icon: "mic-off", label: "mic", active: Audio.sourceMuted, available: true, act: () => Audio.toggleSourceMuted() },
                { icon: "record", label: "record", active: Toggles.recording, available: Toggles.hasRecorder, act: () => Toggles.toggleRecording() },
                { icon: "shield", label: "vpn", active: Toggles.vpnUp, available: Toggles.hasVpn, act: () => Toggles.toggleVpn() },
                { icon: "contrast", label: "dark", active: Toggles.dark, available: true, act: () => Toggles.toggleDark() }
            ]
        ]

        Item {
            required property var modelData

            width: root.width
            height: 86

            Repeater {
                model: parent.modelData

                Item {
                    required property var modelData
                    required property int index

                    x: index * root.cell
                    width: root.cell
                    height: parent.height

                    ToggleCircle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        icon: modelData.icon
                        label: modelData.label
                        active: modelData.active
                        available: modelData.available
                        onToggled: modelData.act()
                    }
                }
            }
        }
    }
}
