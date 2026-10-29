import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.theme

/*
 * Workspaces and the focused window. Occupied reads as a dim dot, active
 * stretches into a capsule.
 */
Pill {
    id: root

    required property string monitorName

    readonly property int count: Config.forMonitor(monitorName, "bar.workspaces.count", 6)
    readonly property real dot: Config.forMonitor(monitorName, "bar.workspaces.dotSize", 6)
    readonly property real activeWidth: Config.forMonitor(monitorName, "bar.workspaces.activeWidth", 18)
    readonly property var modules: Config.forMonitor(monitorName, "bar.islands.left", ["workspaces", "activeWindow"])

    implicitWidth: row.implicitWidth + Theme.space(2) * 2
    level: 0
    floating: true

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.space(2)

        Row {
            id: dots

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(0) + 3
            visible: root.modules.includes("workspaces")

            Repeater {
                model: root.count

                Rectangle {
                    id: wsDot

                    required property int index

                    readonly property int wsId: index + 1
                    readonly property bool active: Hyprland.focusedWorkspace?.id === wsId
                    readonly property bool occupied: Hyprland.workspaces.values.some(w => w.id === wsId)

                    anchors.verticalCenter: parent.verticalCenter
                    width: active ? root.activeWidth : root.dot
                    height: root.dot
                    radius: height / 2
                    color: {
                        if (active)
                            return Theme.dotOn;
                        return occupied ? Qt.alpha(Theme.fg, 0.55) : Theme.dotOff;
                    }

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.standard
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.enterEasing
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.standard
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Hyprland.dispatch(`workspace ${wsDot.wsId}`)
                    }
                }
            }
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
        onWheel: event => Hyprland.dispatch(event.angleDelta.y > 0 ? "workspace e-1" : "workspace e+1")
    }
}
