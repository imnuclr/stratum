import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The dot row, turned on its side. Same sizing and the same paging: a fixed
 * window of `count` dots where workspace 6 of a five-wide row is the first dot
 * of the next five, so going past the end still leaves something focused.
 */
Column {
    id: root

    required property string monitorName

    readonly property int count: Math.max(1, Config.forMonitor(monitorName, "bar.workspaces.count", 6))
    readonly property real size: Config.forMonitor(monitorName, "bar.workspaces.slot", 22)
    readonly property int animMs: Config.forMonitor(monitorName, "bar.workspaces.animMs", 500)

    readonly property int activeId: Hypr.focusedWorkspace?.id ?? 1

    // Which page of `count` workspaces the row is showing. Held rather than
    // bound: a special workspace reports an id outside the run, and recomputing
    // from it would flip the row to a nonsense page and then back.
    property int groupOffset: 0

    function sync() {
        const id = root.activeId;
        if (id < 1)
            return;
        root.groupOffset = Math.floor((id - 1) / root.count) * root.count;
    }

    onActiveIdChanged: sync()
    onCountChanged: sync()
    Component.onCompleted: sync()

    spacing: Config.forMonitor(monitorName, "bar.workspaces.verticalGap", 2)

    Repeater {
        model: root.count

        Item {
            id: cell

            required property int index

            readonly property int wsId: root.groupOffset + cell.index + 1

            width: root.size
            height: root.size

            WorkspaceDot {
                anchors.fill: parent

                focused: root.activeId === cell.wsId
                occupied: Hypr.isOccupied(cell.wsId)
                elsewhere: Hypr.isOccupied(cell.wsId) && Hypr.monitorOf(cell.wsId) !== root.monitorName
                hovered: hover.containsMouse
                pressed: hover.pressed
                animMs: root.animMs
                size: root.size
            }

            MouseArea {
                id: hover

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.focusWorkspace(cell.wsId)
            }
        }
    }
}
