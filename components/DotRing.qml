import QtQuick
import qs.theme

/*
 * Dotted arc gauge. `value` is 0..1 and fills dots clockwise from twelve o'clock.
 */
Item {
    id: root

    property real value: 0
    property real dotSize: Theme.dot
    // As many as fit at the standard spacing, so a big ring has more dots rather
    // than bigger ones.
    property int count: Math.max(12, Math.round(2 * Math.PI * Math.max(1, Math.min(width, height) / 2 - dotSize) / Theme.dotPitch))
    property color onColor: Theme.dotOn
    property color offColor: Theme.dotOff

    /*
     * Dots light by how far the ring has been animated to, not by the raw value,
     * so a reading that jumps from 14 to 40 sweeps through the dots in between
     * instead of snapping. The last dot fades in rather than switching on.
     */
    property real shown: Math.max(0, Math.min(1, value))
    // Off for a ring that is a fixed frame rather than a reading.
    property bool animated: true

    readonly property real ringRadius: Math.min(width, height) / 2 - dotSize
    readonly property real litExact: count * shown

    Behavior on shown {
        enabled: root.animated

        NumberAnimation {
            duration: Theme.sheetMs
            easing.type: Easing.OutCubic
        }
    }

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
            // 0 for an unlit dot, 1 for a lit one, and the fraction between for the
            // dot the sweep is currently passing through.
            readonly property real amount: Math.max(0, Math.min(1, root.litExact - index))

            color: Qt.tint(root.offColor, Qt.alpha(root.onColor, amount))

            Behavior on color {
                ColorAnimation {
                    duration: Theme.micro
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }
        }
    }
}
