import QtQuick
import qs.components
import qs.services
import qs.theme
import qs.utils

/*
 * Network, bluetooth, volume and battery. Each glyph is live and most take an
 * interaction, so the cluster is a control surface rather than a readout.
 *
 * Battery hides entirely when there isn't one, instead of rendering a fake 100%.
 */
Row {
    id: root

    spacing: Theme.space(2)

    // Network — click toggles wifi, and an unroutable connection dims the glyph
    // rather than inventing a separate "connected but no internet" icon.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 16
        implicitHeight: 16

        readonly property color tint: {
            if (!Network.connected)
                return Theme.fgFaint;
            return Network.online ? Theme.fgDim : Theme.warn;
        }

        Glyph {
            anchors.fill: parent
            name: Network.wiredActive ? "ethernet" : "wifi-off"
            size: 16
            color: parent.tint
            visible: Network.wiredActive || !Network.wifiEnabled
        }

        WifiGlyph {
            anchors.fill: parent
            strength: Network.strength
            size: 16
            color: parent.tint
            visible: !Network.wiredActive && Network.wifiEnabled
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            cursorShape: Qt.PointingHandCursor
            onClicked: Network.toggleWifi()
        }
    }

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        name: Bt.enabled ? "bluetooth" : "bluetooth-off"
        color: Bt.connected ? Theme.fg : (Bt.enabled ? Theme.fgDim : Theme.fgFaint)
        size: 16
        visible: Bt.available

        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            cursorShape: Qt.PointingHandCursor
            onClicked: Bt.toggle()
        }
    }

    // Volume — click mutes, scroll adjusts.
    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        name: Icons.volume(Audio.volume, Audio.muted)
        color: Audio.muted ? Theme.fgFaint : Theme.fgDim
        size: 16

        MouseArea {
            anchors.fill: parent
            anchors.margins: -3
            cursorShape: Qt.PointingHandCursor
            onClicked: Audio.toggleMuted()
            onWheel: event => Audio.step(event.angleDelta.y > 0 ? 0.02 : -0.02)
        }
    }

    Battery {
        anchors.verticalCenter: parent.verticalCenter
        visible: Power.hasBattery
    }
}
