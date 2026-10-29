import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Connection detail. Sized by content so the frame can animate to it.
 */
Item {
    id: root

    implicitWidth: 206
    implicitHeight: body.implicitHeight

    Column {
        id: body

        width: parent.width
        spacing: Theme.space(2)

        SectionLabel {
            text: Network.wiredActive ? "Wired" : "Wi-Fi"
        }

        Text {
            id: title

            text: Network.connected ? Network.label : "Not connected"
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 15
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Row {
            spacing: Theme.space(2)
            visible: Network.wifiActive

            DotBar {
                anchors.verticalCenter: parent.verticalCenter
                count: 12
                value: Network.strength / 100
            }

            DotText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Network.strength}`
                size: 13
                color: Theme.fgDim
            }

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                dim: true
                text: "%"
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
        }

        Detail {
            key: "Address"
            value: Network.ipv4
            visible: Network.ipv4.length > 0
        }

        Detail {
            key: "Speed"
            value: `${Network.linkSpeed} Mb/s`
            visible: Network.linkSpeed > 0
        }

        Detail {
            key: "Security"
            value: Network.securityName
            visible: Network.wifiActive
        }

        Detail {
            key: "MAC"
            value: Network.mac
            visible: Network.mac.length > 0
        }

        SectionLabel {
            width: body.width
            wrapMode: Text.WordWrap
            dim: true
            text: Network.online ? "Click to disable Wi-Fi" : "No route to internet"
        }

        component Detail: Row {
            required property string key
            property string value: ""

            width: root.width
            spacing: Theme.space(2)

            SectionLabel {
                width: 62
                dim: true
                text: parent.key
            }

            Text {
                text: parent.value
                color: Theme.fgDim
                font.family: Theme.fontUi
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }
        }
    }
}
