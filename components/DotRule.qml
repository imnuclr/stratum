import QtQuick
import qs.theme

/*
 * A horizontal rule drawn as dots, for dividing stacked sections. The
 * counterpart of DotDivider, which divides columns: same palette and pitch as
 * every other dotted thing in the shell, so the rule reads as part of the
 * material rather than as the one straight edge in it.
 */
Item {
    id: root

    property real pitch: Theme.dotPitch
    property real dotSize: Theme.dot
    property color color: Theme.dotOff

    readonly property int count: Math.max(0, Math.floor(width / pitch))

    implicitHeight: dotSize
    height: dotSize

    Repeater {
        model: root.count

        Rectangle {
            required property int index

            // Centred as a group, so the run is symmetric in the margin rather
            // than starting hard at the left edge.
            x: index * root.pitch + (root.width - root.count * root.pitch) / 2
            width: root.dotSize
            height: root.dotSize
            radius: root.dotSize / 2
            color: root.color
        }
    }
}
