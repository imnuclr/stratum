import QtQuick
import qs.theme

/*
 * Toggle in the shell's inverted-fill language: on is a filled white track with a
 * dark knob, off is a hairline track with a faint one. No accent colour — the
 * accent is reserved for alerts, so a row of switches doesn't read as a warning.
 */
Item {
    id: root

    property bool checked: false
    property bool enabled: true

    signal toggled(bool value)

    implicitWidth: 34
    implicitHeight: 18

    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.fg : "transparent"
        border.width: 1
        border.color: root.checked ? Theme.fg : (hover.containsMouse ? Theme.fg : Theme.lineHi)

        Behavior on color {
            ColorAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    Rectangle {
        id: knob

        y: (parent.height - height) / 2
        x: root.checked ? parent.width - width - 3 : 3
        width: root.checked ? 12 : 10
        height: width
        radius: height / 2
        color: root.checked ? Theme.surface : Theme.fgFaint

        Behavior on x {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.expressive
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
