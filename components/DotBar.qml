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
    /*
     * Lit dots drawn slightly larger than unlit ones. Colour alone separates
     * them only while the two are side by side; the size difference is what
     * makes the filled run readable at a glance across a long bar.
     */
    property real litScale: 1
    property color onColor: Theme.dotOn
    property color offColor: Theme.dotOff

    readonly property int lit: Math.round(count * Math.max(0, Math.min(1, value)))

    spacing: dotSize

    Repeater {
        model: root.count

        // Fixed-width cell with the dot centred inside it, so growing a lit dot
        // does not push the rest of the bar along.
        Item {
            required property int index

            readonly property bool on: index < root.lit

            width: root.dotSize
            height: root.dotSize * root.litScale

            Rectangle {
                anchors.centerIn: parent
                width: parent.on ? root.dotSize * root.litScale : root.dotSize
                height: width
                radius: width / 2
                color: parent.on ? root.onColor : root.offColor

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.micro
                    }
                }
            }
        }
    }
}
