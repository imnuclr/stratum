import QtQuick
import qs.components
import qs.services
import qs.theme

Item {
    id: root

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.space(3)

        SectionLabel {
            text: Netstat.iface.length > 0 ? `net · ${Netstat.iface}` : "net · offline"
        }

        Repeater {
            model: [
                { glyph: "arrow-down", rate: Netstat.rxRate },
                { glyph: "arrow-up", rate: Netstat.txRate }
            ]

            Row {
                required property var modelData

                spacing: Theme.space(2)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: modelData.glyph
                    size: 15
                    color: Theme.fgDim
                }

                DotText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Netstat.humanNumber(modelData.rate)
                    size: 22
                    // Ticks every second; see SystemColumn.
                    plain: true
                }

                SectionLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    dim: true
                    text: Netstat.humanUnit(modelData.rate)
                }
            }
        }
    }

    // Spans the column: the history is the only thing in here with a shape, and
    // a narrow field beside empty space reads as unfinished.
    DotFieldDual {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        rows: 11
        cell: 7.4
        dotSize: 3.6
        upper: Netstat.txHistory
        lower: Netstat.rxHistory
    }
}
