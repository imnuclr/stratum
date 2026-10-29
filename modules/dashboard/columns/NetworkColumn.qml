import QtQuick
import qs.components
import qs.services
import qs.theme

Column {
    id: root

    spacing: Theme.space(3)

    SectionLabel {
        text: Netstat.iface.length > 0 ? `net · ${Netstat.iface}` : "net · offline"
    }

    Repeater {
        model: [
            { glyph: "arrow-down", rate: Netstat.rxRate, scaled: Netstat.rxScaled },
            { glyph: "arrow-up", rate: Netstat.txRate, scaled: Netstat.txScaled }
        ]

        Row {
            required property var modelData

            spacing: Theme.space(2)

            DotRing {
                width: 36
                height: 36
                count: 22
                dotSize: 2.6
                value: modelData.scaled

                Glyph {
                    anchors.centerIn: parent
                    name: modelData.glyph
                    size: 13
                    color: Theme.fgDim
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space(1)

                DotText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Netstat.humanNumber(modelData.rate)
                    size: 21
                }

                SectionLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    dim: true
                    text: Netstat.humanUnit(modelData.rate)
                }
            }
        }
    }

    DotField {
        rows: 5
        cell: 6.4
        dotSize: 3.6
        values: Netstat.rxHistory
    }
}
