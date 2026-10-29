import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.theme

/*
 * Workspace dots. Occupied reads as a dim dot, active stretches into a capsule.
 */
Pill {
    id: root

    required property string monitorName

    readonly property int count: Config.forMonitor(monitorName, "bar.workspaces.count", 6)
    readonly property real dot: Config.forMonitor(monitorName, "bar.workspaces.dotSize", 6)
    readonly property real activeWidth: Config.forMonitor(monitorName, "bar.workspaces.activeWidth", 18)

    implicitWidth: dots.implicitWidth + Theme.space(2) * 2
    level: 0
    floating: true

    Row {
        id: dots

        anchors.centerIn: parent
        spacing: Theme.space(0) + 3

        Repeater {
            model: root.count

            Rectangle {
                required property int index

                readonly property int wsId: index + 1
                readonly property var ws: Hyprland.workspaces.values.find(w => w.id === wsId) ?? null
                readonly property bool active: Hyprland.focusedWorkspace?.id === wsId
                readonly property bool occupied: ws !== null

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
                    onClicked: Hyprland.dispatch(`workspace ${parent.wsId}`)
                }
            }
        }
    }
}
