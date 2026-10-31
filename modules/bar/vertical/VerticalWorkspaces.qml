import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Workspaces as a column of dots, the focused one drawn as a capsule.
 *
 * A dot also says which display its workspace is on, because with two monitors
 * a flat list of numbers gives no clue where switching to one will take you.
 * Filled means this display; a ring means the other one. The distinction is
 * drawn rather than labelled — a bar this narrow has no room for monitor names,
 * and the shape is readable at a glance once seen.
 */
Column {
    id: root

    required property string monitorName

    readonly property int count: Config.get("bar.workspaces.count", 6)
    // Not a fixed run: anything that exists beyond the configured count gets a
    // dot too, so switching past the end still shows where you are.
    readonly property var ids: Hypr.visibleIds(root.count)
    readonly property int focused: Hypr.focusedWorkspace?.id ?? 1

    readonly property real dot: 5
    readonly property real pitch: 16
    readonly property real capsule: 18

    spacing: pitch - dot

    Repeater {
        model: root.ids

        Item {
            id: slot

            required property var modelData

            readonly property int id: slot.modelData
            readonly property bool isFocused: root.focused === slot.id
            readonly property bool occupied: Hypr.isOccupied(slot.id)
            readonly property string home: Hypr.monitorOf(slot.id)
            // An unused workspace belongs to no display yet, so it is drawn as
            // neither — a faint dot, the way it always was.
            readonly property bool elsewhere: slot.occupied && slot.home !== root.monitorName

            width: root.dot
            height: slot.isFocused ? root.capsule : root.dot

            Behavior on height {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.expressive
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2

                // A workspace on another display is drawn as a ring: the same dot
                // with its middle taken out, so the column reads as one set of
                // workspaces rather than two unrelated groups.
                color: slot.elsewhere
                    ? "transparent"
                    : (slot.isFocused ? Theme.fg : (slot.occupied ? Theme.fgDim : Theme.dotOff))
                border.width: slot.elsewhere ? 1 : 0
                border.color: slot.isFocused ? Theme.fg : Theme.fgDim

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -5
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.focusWorkspace(slot.id)
            }
        }
    }
}
