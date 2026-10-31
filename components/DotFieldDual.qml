import QtQuick
import qs.theme

/*
 * Two sparklines mirrored about a centre line: `upper` grows up from the middle,
 * `lower` grows down. For a pair of readings that belong together and move
 * independently, like upload against download.
 *
 * Growing from the centre rather than hanging off the two edges puts the
 * baseline where the eye reads it — at rest the graph is a flat line through the
 * middle, and each series departs from the same place, so their sizes can be
 * compared directly.
 */
Row {
    id: root

    property var upper: []
    property var lower: []
    property int rows: 8
    property real cell: Theme.dotPitch
    property real dotSize: Theme.dot
    property color onColor: Theme.dotOn
    property color offColor: Theme.dotOff

    /*
     * An odd row count so there is a true middle row to act as the baseline; the
     * halves above and below it are what the two series fill.
     */
    readonly property int oddRows: rows % 2 === 0 ? rows + 1 : rows
    readonly property int half: (oddRows - 1) / 2
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
                model: root.oddRows

                Rectangle {
                    required property int index

                    // Distance from the centre row, which is always lit.
                    readonly property int fromCentre: index - root.half
                    readonly property bool on: fromCentre === 0
                        || (fromCentre < 0 && -fromCentre <= column.upLit)
                        || (fromCentre > 0 && fromCentre <= column.downLit)

                    width: root.dotSize
                    height: root.dotSize
                    radius: root.dotSize / 2
                    color: on ? root.onColor : root.offColor

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
    }
}
