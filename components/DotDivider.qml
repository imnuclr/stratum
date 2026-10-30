import QtQuick
import qs.theme

/*
 * A vertical rule drawn as dots rather than a hairline, for dividing the
 * dashboard's columns. A solid line is the one straight edge in a layout
 * otherwise built entirely from dots, and it reads as a different material.
 */
Item {
    id: root

    property real spacingY: 6
    property real dotSize: Theme.dot
    // Theme.line is sized for a hairline; broken into dots at this pitch it
    // disappears, so the rule carries the dot palette's "off" value instead.
    property color color: Theme.dotOff

    readonly property int count: Math.max(0, Math.floor(height / spacingY))

    implicitWidth: dotSize

    Repeater {
        model: root.count

        Rectangle {
            required property int index

            x: (root.width - root.dotSize) / 2
            // Centred as a group, so the run of dots is symmetric in the gap
            // rather than starting hard at the top.
            y: index * root.spacingY + (root.height - root.count * root.spacingY) / 2
            width: root.dotSize
            height: root.dotSize
            radius: root.dotSize / 2
            color: root.color
        }
    }
}
