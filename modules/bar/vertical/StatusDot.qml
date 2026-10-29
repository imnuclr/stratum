import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The mark at the head of the bar: a dot ring with a filled centre, which opens
 * the dashboard. It is the one place the accent appears on the bar, so it reads
 * as the shell's own control rather than as another status reading.
 */
Item {
    id: root

    readonly property bool active: Shell.openPanel.length > 0

    implicitWidth: 42
    implicitHeight: 42

    DotRing {
        anchors.fill: parent
        count: 24
        dotSize: 2.6
        // A full ring, not a meter: this is a frame, not a reading.
        value: 1
        onColor: hover.hovered || root.active ? Theme.fg : Theme.dotOff
    }

    Rectangle {
        anchors.centerIn: parent
        width: 10
        height: 10
        radius: width / 2
        color: Theme.accent
        scale: hover.hovered || root.active ? 1.2 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.expressive
            }
        }
    }

    HoverHandler {
        id: hover
    }


}
