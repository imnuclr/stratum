import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Tray, status cluster and the dot-grid control centre trigger.
 */
Pill {
    id: root

    required property string monitorName

    readonly property var modules: Config.forMonitor(monitorName, "bar.islands.right", ["tray", "status", "controlCentre"])

    implicitWidth: row.implicitWidth + Theme.space(2) * 2
    level: 0
    floating: true

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.space(2)

        Tray {
            id: tray

            anchors.verticalCenter: parent.verticalCenter
            visible: root.modules.includes("tray") && hasItems
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: Theme.lineHi
            visible: tray.visible
        }

        StatusCluster {
            monitorName: root.monitorName
            anchors.verticalCenter: parent.verticalCenter
            visible: root.modules.includes("status")
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 14
            color: Theme.lineHi
            visible: root.modules.includes("controlCentre")
        }

        // 3x3 dot grid — the control centre's trigger, never a hamburger.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: gridBtn.implicitWidth
            implicitHeight: gridBtn.implicitHeight
            visible: root.modules.includes("controlCentre")

            Grid {
                id: gridBtn

                columns: 3
                spacing: 2.5

                Repeater {
                    model: 9

                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: gridMouse.containsMouse || Shell.openPanel === "controlCentre" ? Theme.fg : Theme.fgDim

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.micro
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: gridMouse

                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Shell.toggle("controlCentre")
            }
        }
    }
}
