import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Throughput against the highest rate seen this session, so the meter is
 * meaningful on whatever link this machine actually has.
 */
Column {
    spacing: Theme.space(2)

    Row {
        spacing: Theme.space(3)

        DotRing {
            width: 74
            height: 74
            count: 40
            dotSize: 3.2
            value: Netstat.rxScaled

            DotText {
                anchors.centerIn: parent
                text: Network.wifiActive ? `${Network.strength}` : (Network.connected ? "··" : "--")
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
                values: Netstat.rxHistory
            }

            SectionLabel {
                text: Network.connected ? Network.label : "offline"
            }

            SectionLabel {
                dim: true
                text: `↓ ${Netstat.human(Netstat.rxRate)}/s · ↑ ${Netstat.human(Netstat.txRate)}/s`
            }
        }
    }
}
