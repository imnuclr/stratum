import QtQuick
import qs.theme

/*
 * Dot grid sparkline. `values` is an array of 0..1 — one entry per column,
 * oldest first. Columns fill from the bottom.
 */
Row {
    id: root

    property var values: []
    property int rows: 6
    property real cell: Theme.dotPitch
    property real dotSize: Theme.dot
    property color onColor: Theme.dotOn
    property color offColor: Theme.dotOff

    // Columns can be spread wider than the dots are apart, to fill a width,
    // without the dots themselves changing size.
    property real columnSpacing: -1

    spacing: root.columnSpacing >= 0 ? root.columnSpacing : cell - dotSize

    Repeater {
        model: root.values.length

        Column {
            id: column

            required property int index

            readonly property int lit: Math.round(root.rows * Math.max(0, Math.min(1, root.values[index] ?? 0)))

            spacing: root.cell - root.dotSize

            Repeater {
                model: root.rows

                Rectangle {
                    required property int index

                    // Row 0 is the top of the column, so invert to fill upward.
                    readonly property bool on: (root.rows - index) <= column.lit

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
