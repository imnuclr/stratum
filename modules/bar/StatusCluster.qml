import QtQuick
import qs.components
import qs.services
import qs.theme
import qs.utils

/*
 * Network, bluetooth, volume and battery. Each is live, takes a click, and
 * raises a hover popout with its own detail.
 *
 * Battery hides entirely when there isn't one, rather than rendering a fake 100%.
 */
Row {
    id: root

    required property string monitorName

    spacing: Theme.space(2)

    // Network — click toggles wifi. An unroutable connection tints the glyph
    // rather than inventing a separate "connected but no internet" icon.
    StatusItem {
        popout: "network"

        readonly property color tint: {
            if (!Network.connected)
                return Theme.fgFaint;
            return Network.online ? Theme.fgDim : Theme.warn;
        }

        onActivated: Wifi.toggle()

        Glyph {
            anchors.fill: parent
            name: Network.wiredActive ? "ethernet" : "wifi-off"
            size: 16
            color: parent.tint
            visible: Network.wiredActive || !Wifi.enabled
        }

        WifiGlyph {
            anchors.fill: parent
            strength: Network.strength
            size: 16
            color: parent.tint
            visible: !Network.wiredActive && Wifi.enabled
        }
    }

    StatusItem {
        popout: "bluetooth"
        visible: Bt.available

        onActivated: Bt.toggle()

        Glyph {
            anchors.fill: parent
            name: Bt.enabled ? "bluetooth" : "bluetooth-off"
            size: 16
            color: Bt.connected ? Theme.fg : (Bt.enabled ? Theme.fgDim : Theme.fgFaint)
        }
    }

    // Volume — click mutes, scroll adjusts.
    StatusItem {
        popout: "audio"

        onActivated: Audio.toggleMuted()
        onScrolled: delta => Audio.step(delta > 0 ? 0.02 : -0.02)

        Glyph {
            anchors.fill: parent
            name: Icons.volume(Audio.volume, Audio.muted)
            size: 16
            color: Audio.muted ? Theme.fgFaint : Theme.fgDim
        }
    }

    Battery {
        anchors.verticalCenter: parent.verticalCenter
        visible: Power.hasBattery
    }

    /*
     * Shared hover/click behaviour. Each item reports its own centre in bar-window
     * coordinates so the popout can anchor under it.
     */
    component StatusItem: Item {
        id: item

        property string popout: ""

        signal activated
        signal scrolled(real delta)

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 16
        implicitHeight: 16

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.space(1)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                const centre = item.mapToItem(null, item.width / 2, 0);
                Popouts.show(item.popout, centre.x, root.monitorName);
            }

            onExited: Popouts.release(item.popout)
            onClicked: item.activated()
            onWheel: event => item.scrolled(event.angleDelta.y)
        }
    }
}
