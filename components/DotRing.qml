import QtQuick
import qs.theme

/*
 * Dotted arc gauge. `value` is 0..1 and fills dots clockwise from twelve o'clock.
 */
Item {
    id: root

    property real value: 0
    property int count: 44
    property real dotSize: 3.8
    property color onColor: Theme.dotOn
    property color offColor: Theme.dotOff

    readonly property real ringRadius: Math.min(width, height) / 2 - dotSize
    readonly property int lit: Math.round(count * Math.max(0, Math.min(1, value)))

    implicitWidth: 86
    implicitHeight: 86

    Repeater {
        model: root.count

        Rectangle {
            required property int index

            readonly property real angle: (index / root.count) * 2 * Math.PI - Math.PI / 2

            width: root.dotSize
            height: root.dotSize
            radius: root.dotSize / 2
            x: root.width / 2 + Math.cos(angle) * root.ringRadius - width / 2
            y: root.height / 2 + Math.sin(angle) * root.ringRadius - height / 2
            color: index < root.lit ? root.onColor : root.offColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.standard
                }
            }
        }
    }
}
