import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Status cluster and the dot-grid control centre trigger. Service-backed glyphs
 * land here in phase 2; for now the grid button is wired so the panel machinery
 * can be exercised end to end.
 */
Pill {
    id: root

    required property string monitorName

    implicitWidth: row.implicitWidth + Theme.space(2) * 2
    level: 0
    floating: true
    hovered: mouse.containsMouse

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.space(2)

        // 3x3 dot grid — the control centre's trigger, never a hamburger.
        Grid {
            anchors.verticalCenter: parent.verticalCenter
            columns: 3
            spacing: 2.5

            Repeater {
                model: 9

                Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    color: mouse.containsMouse ? Theme.fg : Theme.fgDim

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.micro
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: Shell.toggle("controlCentre")
    }
}
