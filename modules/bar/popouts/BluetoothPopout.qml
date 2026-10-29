import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Adapter state and connected devices, with battery where the device reports it.
 */
Item {
    id: root

    implicitWidth: 212
    implicitHeight: body.implicitHeight

    Column {
        id: body

        width: parent.width
        spacing: Theme.space(2)

        SectionLabel {
            text: "Bluetooth"
        }

        Text {
            text: Bt.enabled ? (Bt.connected ? Bt.label : "On · nothing connected") : "Off"
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 15
            font.weight: Font.Medium
            width: root.width
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
            visible: Bt.connectedDevices.length > 0
        }

        Repeater {
            model: Bt.connectedDevices

            Row {
                id: device

                required property var modelData

                width: root.width
                spacing: Theme.space(2)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.width - 76
                    elide: Text.ElideRight
                    text: device.modelData.name
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                DotBar {
                    anchors.verticalCenter: parent.verticalCenter
                    count: 8
                    value: device.modelData.battery
                    visible: device.modelData.batteryAvailable
                }

                DotText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.round(device.modelData.battery * 100)}`
                    size: 12
                    color: Theme.fgDim
                    visible: device.modelData.batteryAvailable
                }
            }
        }

        SectionLabel {
            width: body.width
            wrapMode: Text.WordWrap
            dim: true
            text: Bt.enabled ? "Click to turn off" : "Click to turn on"
        }
    }
}
