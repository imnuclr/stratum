import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Workspaces as a column of dots, the focused one drawn as a capsule.
 *
 * The capsule travels rather than jumping: the same asymmetric timing the
 * horizontal bar uses, where the trailing edge runs longer than the leading one
 * so the shape stretches as it moves.
 */
Column {
    id: root

    required property string monitorName

    readonly property int count: Config.get("bar.workspaces.count", 6)
    readonly property int focused: Hypr.focusedWorkspace?.id ?? 1

    readonly property real dot: 5
    readonly property real pitch: 16
    readonly property real capsule: 18

    spacing: pitch - dot

    Repeater {
        model: root.count

        Item {
            id: slot

            required property int index

            readonly property int id: index + 1
            readonly property bool isFocused: root.focused === slot.id
            readonly property bool occupied: Hypr.isOccupied(slot.id)

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
                color: slot.isFocused ? Theme.fg : (slot.occupied ? Theme.fgDim : Theme.dotOff)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.standard
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
