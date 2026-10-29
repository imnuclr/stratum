import QtQuick
import qs.theme

/*
 * A small bitmap drawn in dots.
 *
 * The pattern is a list of equal-length strings, one per row, where '#' is a lit
 * dot and anything else is empty. Unlit cells are left blank rather than drawn
 * dim: these sit next to real meters, where a dim dot means "off" and would read
 * as part of the reading rather than as background.
 */
Item {
    id: root

    property var pattern: []
    property real cell: 5
    property real dotSize: 3.4
    property color color: Theme.dotOn

    readonly property int rows: pattern.length
    readonly property int columns: rows > 0 ? pattern[0].length : 0

    implicitWidth: columns * cell
    implicitHeight: rows * cell

    Repeater {
        model: root.rows * root.columns

        Rectangle {
            required property int index

            readonly property int row: Math.floor(index / root.columns)
            readonly property int column: index % root.columns

            x: column * root.cell + (root.cell - root.dotSize) / 2
            y: row * root.cell + (root.cell - root.dotSize) / 2
            width: root.dotSize
            height: root.dotSize
            radius: root.dotSize / 2
            color: root.color
            visible: root.pattern[row]?.[column] === "#"
        }
    }
}
