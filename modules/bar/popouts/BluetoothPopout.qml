import QtQuick
import Quickshell.Bluetooth
import qs.components
import qs.services
import qs.theme
import qs.utils

/*
 * Adapter state, discovery, and the paired or in-range devices.
 *
 * Discovery is left under manual control rather than turned on with the popout:
 * it is a battery and radio cost, and an unprompted scan reshuffles the list
 * while someone is trying to click a row in it.
 */
Item {
    id: root

    implicitWidth: 268
    implicitHeight: body.implicitHeight

    Column {
        id: body

        width: parent.width
        spacing: Theme.space(2)

        Text {
            text: "Bluetooth"
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 15
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Row {
            width: body.width

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: body.width - 34
                text: "Enabled"
                dim: false
            }

            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Bt.enabled
                enabled: Bt.available
                onToggled: value => Bt.setEnabled(value)
            }
        }

        Row {
            width: body.width

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: body.width - 34
                text: "Discovering"
                dim: false
            }

            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Bt.discovering
                enabled: Bt.enabled
                onToggled: value => Bt.setDiscovering(value)
            }
        }

        SectionLabel {
            dim: true
            text: {
                if (!Bt.enabled)
                    return "Bluetooth is off";
                const n = Bt.devices.length;
                return n === 1 ? "1 device available" : `${n} devices available`;
            }
        }

        Repeater {
            model: Bt.enabled ? Bt.sorted : []

            Row {
                id: entry

                required property BluetoothDevice modelData

                readonly property bool busy: modelData.state === BluetoothDeviceState.Connecting
                    || modelData.state === BluetoothDeviceState.Disconnecting

                width: body.width
                spacing: Theme.space(1)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Icons.bluetoothDevice(entry.modelData.icon)
                    size: 15
                    color: entry.modelData.connected ? Theme.fg : Theme.fgDim
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: body.width - 118
                    leftPadding: Theme.space(1)
                    elide: Text.ElideRight
                    text: entry.modelData.name
                    color: entry.modelData.connected ? Theme.fg : Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: entry.modelData.connected ? Font.Medium : Font.Normal
                    renderType: Text.NativeRendering
                }

                DotText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: entry.modelData.connected && entry.modelData.batteryAvailable
                    text: `${Math.round(entry.modelData.battery * 100)}`
                    size: 12
                    color: entry.modelData.battery < 0.2 ? Theme.crit : Theme.fgDim
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    icon: entry.modelData.connected ? "link-off" : "link"
                    active: entry.modelData.connected
                    enabled: !entry.busy
                    onClicked: Bt.toggleDevice(entry.modelData)
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    icon: "trash"
                    danger: true
                    visible: entry.modelData.bonded
                    onClicked: Bt.forget(entry.modelData)
                }
            }
        }

        ActionButton {
            width: body.width
            icon: "settings"
            text: "Open settings"
            // Nothing to open if no manager is installed.
            visible: Bt.settingsApp.length > 0
            onClicked: Bt.openSettings()
        }
    }
}
