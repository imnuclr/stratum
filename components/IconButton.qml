import QtQuick
import qs.theme

/*
 * Round icon button for per-row actions. Inverts when it represents an active
 * state, so "connected" and "connect" are the same control in two states.
 */
Item {
    id: root

    property string icon: ""
    property bool active: false
    property bool enabled: true
    property bool danger: false
    property real size: 24

    signal clicked

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.35

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: {
            if (root.active)
                return Theme.fg;
            return hover.containsMouse ? Theme.surfaceTop : "transparent";
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.micro
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    Glyph {
        anchors.centerIn: parent
        name: root.icon
        size: Math.round(root.size * 0.58)
        color: {
            if (root.active)
                return Theme.surface;
            if (root.danger)
                return hover.containsMouse ? Theme.accent : Theme.fgFaint;
            return hover.containsMouse ? Theme.fg : Theme.fgDim;
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.micro
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
