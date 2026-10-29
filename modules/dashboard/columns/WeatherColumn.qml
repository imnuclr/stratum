import QtQuick
import qs.components
import qs.services
import qs.theme
import qs.utils

Column {
    id: root

    spacing: Theme.space(2)

    SectionLabel {
        text: Weather.condition.length > 0
            ? Weather.condition
            : (Weather.error.length > 0 ? Weather.error : "loading")
    }

    Row {
        spacing: Theme.space(2)

        DotMatrix {
            anchors.verticalCenter: parent.verticalCenter
            pattern: WeatherGlyphs.forCode(Weather.code, Weather.day)
            cell: 6.5
            dotSize: 4.4
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            DotText {
                text: Weather.ready ? `${Math.round(Weather.temperature)}` : "--"
                size: 40
            }

            // Raised, not centred: a degree sign sits on the cap line.
            DotText {
                y: 2
                text: "°"
                size: 18
            }
        }
    }

    SectionLabel {
        dim: true
        visible: Weather.ready
        text: `feels ${Math.round(Weather.apparent)}° · ${Math.round(Weather.windSpeed)} m/s`
    }

    Row {
        spacing: Theme.space(3)

        Repeater {
            model: Weather.daily.slice(0, 4)

            Column {
                required property var modelData

                spacing: Theme.space(1)

                SectionLabel {
                    text: modelData.day
                }

                DotMatrix {
                    // Forecast glyphs always use the daytime variant; a row of
                    // crescent moons for four consecutive days reads as a bug.
                    pattern: WeatherGlyphs.forCode(modelData.code, true)
                    cell: 4.4
                    dotSize: 3
                }

                DotText {
                    text: `${Math.round(modelData.max)}°`
                    size: 19
                }

                DotText {
                    text: `${Math.round(modelData.min)}°`
                    size: 15
                    color: Theme.fgFaint
                }
            }
        }
    }
}
