import QtQuick
import qs.components
import qs.services
import qs.theme
import qs.utils

Item {
    id: root

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
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
                    size: 44
                }

                // Raised, not centred: a degree sign sits on the cap line.
                DotText {
                    y: 3
                    text: "°"
                    size: 19
                }
            }
        }

        SectionLabel {
            dim: true
            visible: Weather.ready
            text: `feels ${Math.round(Weather.apparent)}° · ${Math.round(Weather.windSpeed)} m/s`
        }
    }

    // Equal cells across the full width, each centred, so the four days read as
    // one row rather than as a list that happens to be horizontal.
    Row {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        Repeater {
            model: Weather.daily.slice(0, 4)

            Item {
                required property var modelData

                width: parent.width / 4
                height: day.implicitHeight

                Column {
                    id: day

                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.space(2)

                    SectionLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.day
                    }

                    Glyph {
                        anchors.horizontalCenter: parent.horizontalCenter
                        // Always the daytime variant: a row of crescent moons
                        // for four consecutive days reads as a bug.
                        name: WeatherGlyphs.outlineForCode(modelData.code, true)
                        size: 23
                        stroke: 1.5
                        color: Theme.fgDim
                    }

                    DotText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${Math.round(modelData.max)}°`
                        size: 20
                    }

                    DotText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${Math.round(modelData.min)}°`
                        size: 16
                        color: Theme.fgFaint
                    }
                }
            }
        }
    }
}
