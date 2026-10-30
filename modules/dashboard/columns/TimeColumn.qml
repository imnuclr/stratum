import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Head at the top, sun times anchored to the bottom, so the column fills its
 * height rather than stacking from the top and leaving a gap.
 */
Item {
    id: root

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.space(2)

        SectionLabel {
            text: Time.format("dddd")
        }

        DotText {
            text: Time.format(Time.hm)
            size: 60
        }

        SectionLabel {
            dim: true
            text: `${Time.format("d MMMM")} · week ${Time.weekNumber()}`
        }

        DotBar {
            readonly property real pitch: dotSize * 2
            count: Math.max(8, Math.floor((parent.width + dotSize) / pitch))
            litScale: 1.5
            value: Time.dayProgress
        }
    }

    Item {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: childrenRect.height

        // Sun times come from the weather forecast, so they are absent until it
        // resolves and there is nothing useful to show in the meantime.
        Item {
            width: parent.width
            height: rise.height
            visible: Weather.sunrise.length > 0

            Row {
                id: rise

                spacing: Theme.space(2)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "sun"
                    size: 14
                    color: Theme.fgFaint
                }

                DotText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.sunrise
                    size: 16
                    color: Theme.fgFaint
                }
            }

            // Pinned to the far side rather than spaced from sunrise: the pair
            // reads as the ends of the day, which is also what the bar above
            // measures.
            Row {
                anchors.right: parent.right
                spacing: Theme.space(2)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "moon"
                    size: 14
                    color: Theme.fgFaint
                }

                DotText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.sunset
                    size: 16
                    color: Theme.fgFaint
                }
            }
        }
    }
}
