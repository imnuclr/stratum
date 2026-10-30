import QtQuick
import qs.theme

/*
 * Draggable level, drawn as dots so it reads as the same family as DotBar.
 * Dragging sets the value continuously; the wheel steps it.
 */
Item {
    id: root

    property real value: 0
    property int count: 24
    property real dotSize: Theme.dot
    property real step: 0.02
    property bool enabled: true

    signal moved(real value)

    implicitHeight: 18
    opacity: enabled ? 1 : 0.4

    readonly property int lit: Math.round(count * Math.max(0, Math.min(1, value)))

    Row {
        id: dots

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: (parent.width - root.count * root.dotSize) / (root.count - 1)

        Repeater {
            model: root.count

            Rectangle {
                required property int index

                width: root.dotSize
                height: root.dotSize
                radius: height / 2
                color: index < root.lit ? Theme.fg : Theme.dotOff
                scale: drag.containsMouse && index < root.lit ? 1.3 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }
            }
        }
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor

        function apply(x) {
            root.moved(Math.max(0, Math.min(1, (x + 4) / root.width)));
        }

        onPressed: event => apply(event.x)
        onPositionChanged: event => {
            if (pressed)
                apply(event.x);
        }
        onWheel: event => root.moved(Math.max(0, Math.min(1,
            root.value + (event.angleDelta.y > 0 ? root.step : -root.step))))
    }
}
