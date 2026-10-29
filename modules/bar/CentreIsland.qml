import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Clock and date. Clicking opens the dashboard, which grows from this island.
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

        DotText {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.format("HH:mm")
            size: Math.round(root.height * 0.5)
            color: Theme.fg
        }

        SectionLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.format("ddd d MMM")
            visible: Config.forMonitor(root.monitorName, "bar.islands.centre", []).includes("date")
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: Shell.toggle("dashboard")
    }
}
