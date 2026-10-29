import QtQuick
import qs.theme

/*
 * Two sparklines sharing one grid: `upper` hangs down from the top edge,
 * `lower` rises from the bottom. For a pair of readings that belong together
 * and move independently, like upload against download.
 *
 * Drawing them as two separate fields would imply two separate measurements;
 * sharing the grid and meeting in the middle says they are one link.
 */
Row {
    id: root

    property var upper: []
    property var lower: []
    property int rows: 8
    property real cell: 7
    property real dotSize: 4.2
    property color onColor: Theme.dotOn
    property color offColor: Theme.dotOff

    // Odd row counts leave an unreachable middle row, which reads as a dead
    // line through the graph.
    readonly property int half: Math.floor(rows / 2)
    readonly property int columns: Math.max(upper.length, lower.length)

    spacing: cell - dotSize

    Repeater {
        model: root.columns

        Column {
            id: column

            required property int index

            readonly property int upLit: Math.round(root.half * Math.max(0, Math.min(1, root.upper[index] ?? 0)))
            readonly property int downLit: Math.round(root.half * Math.max(0, Math.min(1, root.lower[index] ?? 0)))

            spacing: root.cell - root.dotSize

            Repeater {
                model: root.rows

                Rectangle {
                    required property int index

                    readonly property bool isUpper: index < root.half
                    readonly property bool on: isUpper
                        ? index < column.upLit
                        : (root.rows - index) <= column.downLit

                    width: root.dotSize
                    height: root.dotSize
                    radius: root.dotSize / 2
                    color: on ? root.onColor : root.offColor

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.micro
                        }
                    }
                }
            }
        }
    }
}
