import QtQuick
import qs.components
import qs.modules.bar
import qs.services
import qs.theme

/*
 * Keyboard layout, network, battery: what you would want to know before logging
 * in. No battery on a desktop, and then there is nothing to show for it.
 */
Row {
    id: root

    property real u: 1

    spacing: 16 * root.u

    LockLabel {
        anchors.verticalCenter: parent.verticalCenter
        u: root.u
        text: Keyboard.code
        visible: text.length > 0
    }

    WifiGlyph {
        anchors.verticalCenter: parent.verticalCenter
        size: 20 * root.u
        strength: Network.strength
        color: Theme.fgBright
        visible: !Network.wiredActive && Wifi.enabled
    }

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        name: "ethernet"
        size: 20 * root.u
        color: Theme.fgBright
        visible: Network.wiredActive
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * root.u
        visible: Power.hasBattery

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 24 * root.u
            height: 16 * root.u

            scale: root.u
            transformOrigin: Item.Left

            Battery {
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        LockLabel {
            anchors.verticalCenter: parent.verticalCenter
            u: root.u
            text: `${Math.round(Power.percentage * 100)}`
        }
    }
}
