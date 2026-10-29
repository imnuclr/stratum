import QtQuick
import qs.theme

/*
 * Row of dots for progress and load. Used for day progress, track position
 * and per-process CPU share.
 */
Row {
    id: root

    property real value: 0
    property int count: 16
    property real dotSize: 3.4
    property color onColor: Theme.dotOn
    property color offColor: Theme.dotOff

    readonly property int lit: Math.round(count * Math.max(0, Math.min(1, value)))

    spacing: dotSize

    Repeater {
        model: root.count

        Rectangle {
            required property int index

            width: root.dotSize
            height: root.dotSize
            radius: root.dotSize / 2
            color: index < root.lit ? root.onColor : root.offColor

            Behavior on color {
                ColorAnimation {
                    duration: Theme.micro
                }
            }
        }
    }
}
