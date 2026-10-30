import QtQuick
import qs.components
import qs.services
import qs.theme
import qs.utils

/*
 * The weather as a disc: a dotted picture of the sky, the temperature in large
 * dot-matrix numerals, and the condition with today's low and high.
 */
Item {
    id: root

    readonly property real unit: Math.min(root.width, root.height)

    Column {
        anchors.centerIn: parent
        spacing: Math.round(root.unit * 0.04)

        DotMatrix {
            anchors.horizontalCenter: parent.horizontalCenter
            pattern: WeatherGlyphs.forCode(Weather.code, Weather.day)
            cell: Math.max(3, root.unit * 0.034)
            dotSize: cell * 0.7
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            DotText {
                text: Weather.ready ? `${Math.round(Weather.temperature)}` : "--"
                size: root.unit * 0.27
                plain: true
            }

            DotText {
                y: root.unit * 0.02
                text: "°"
                size: root.unit * 0.13
                plain: true
            }
        }

        SectionLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const c = Weather.condition.length > 0 ? Weather.condition : "weather";
                return isNaN(Weather.todayMax) ? c : `${c} · ${Math.round(Weather.todayMin)}°/${Math.round(Weather.todayMax)}°`;
            }
            color: Theme.fgDim
        }
    }
}
