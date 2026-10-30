import QtQuick
import qs.components
import qs.services
import qs.theme
import qs.utils

/*
 * The weather as a disc: a dotted picture of the sky, the temperature, and a line.
 */
Item {
    id: root

    Column {
        anchors.centerIn: parent
        spacing: Theme.space(1)

        DotMatrix {
            anchors.horizontalCenter: parent.horizontalCenter
            pattern: WeatherGlyphs.forCode(Weather.code, Weather.day)
            cell: 5
            dotSize: 3.6
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 1

            DotText {
                text: Weather.ready ? `${Math.round(Weather.temperature)}` : "--"
                size: Math.max(20, root.height * 0.2)
                plain: true
            }

            DotText {
                y: 2
                text: "°"
                size: Math.max(10, root.height * 0.1)
                plain: true
            }
        }

        SectionLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Weather.condition.length > 0 ? Weather.condition : "weather"
            color: Theme.fgBright
        }
    }
}
