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

    property var item: ({})
    property bool live: true

    readonly property real unit: Math.min(root.width, root.height)

    Column {
        anchors.centerIn: parent
        spacing: root.unit * 0.03

        DotMatrix {
            anchors.horizontalCenter: parent.horizontalCenter
            pattern: WeatherGlyphs.forCode(Weather.code, Weather.day)
            cell: Math.max(3, root.unit * 0.05)
            dotSize: cell * 0.72
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            DotText {
                text: Weather.ready ? `${Math.round(Weather.temperature)}` : "--"
                size: root.unit * 0.34
                plain: true
            }

            DotText {
                y: root.unit * 0.03
                text: "°"
                size: root.unit * 0.15
                plain: true
            }
        }

        SectionLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: {
                const c = Weather.condition.length > 0 ? Weather.condition : "weather";
                return isNaN(Weather.todayMax) ? c : `${c} · ${Math.round(Weather.todayMin)}°/${Math.round(Weather.todayMax)}°`;
            }
            color: Theme.fgBright
        }
    }
}
