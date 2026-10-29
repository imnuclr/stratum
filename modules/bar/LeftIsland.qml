import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Workspaces and the focused window. Occupied reads as a dim dot, active
 * stretches into a capsule.
 */
Pill {
    id: root

    required property string monitorName

    readonly property var modules: Config.forMonitor(monitorName, "bar.islands.left", ["workspaces", "activeWindow"])

    implicitWidth: row.implicitWidth + Theme.space(2) * 2
    level: 0
    floating: true

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.space(2)

        Workspaces {
            id: dots

            monitorName: root.monitorName
            anchors.verticalCenter: parent.verticalCenter
            visible: root.modules.includes("workspaces")
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: Theme.lineHi
            visible: dots.visible && window.visible
        }

        ActiveWindow {
            id: window

            anchors.verticalCenter: parent.verticalCenter
            visible: root.modules.includes("activeWindow") && present
        }
    }

    // Scrolling anywhere on the island changes workspace.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => Hypr.focusWorkspaceRelative(event.angleDelta.y > 0 ? -1 : 1)
    }
}
