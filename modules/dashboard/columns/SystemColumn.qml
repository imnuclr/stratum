import QtQuick
import qs.components
import qs.services
import qs.theme

Column {
    spacing: Theme.space(2)

    Row {
        spacing: Theme.space(3)

        DotRing {
            width: 74
            height: 74
            count: 40
            dotSize: 3.2
            value: SysStats.cpu

            DotText {
                anchors.centerIn: parent
                text: `${Math.round(SysStats.cpu * 100)}`
                size: 17
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(1)

            DotField {
                rows: 6
                cell: 7
                dotSize: 4
                values: SysStats.cpuHistory
            }

            SectionLabel {
                dim: true
                text: `mem ${Math.round(SysStats.memory * 100)}% · ${SysStats.memoryLabel}`
            }

            SectionLabel {
                dim: true
                visible: SysStats.temperature > 0
                text: `cpu ${Math.round(SysStats.temperature)}°C`
            }
        }
    }
}
