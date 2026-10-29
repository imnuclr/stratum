import QtQuick
import qs.components
import qs.services
import qs.theme

Column {
    spacing: Theme.space(2)

    SectionLabel {
        text: Time.format("dddd")
    }

    DotText {
        text: Time.format("HH:mm")
        size: 52
    }

    SectionLabel {
        dim: true
        text: `${Time.format("d MMMM")} · week ${Time.weekNumber()}`
    }

    DotBar {
        count: 34
        value: Time.dayProgress
    }

    // Sun times come from the weather forecast, so they are absent until it
    // resolves and there is nothing useful to show in the meantime.
    Row {
        spacing: Theme.space(4)
        visible: Weather.sunrise.length > 0

        Row {
            spacing: Theme.space(1)

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "sun"
                size: 13
                color: Theme.fgFaint
            }

            DotText {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.sunrise
                size: 15
                color: Theme.fgFaint
            }
        }

        Row {
            spacing: Theme.space(1)

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "moon"
                size: 13
                color: Theme.fgFaint
            }

            DotText {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.sunset
                size: 15
                color: Theme.fgFaint
            }
        }
    }
}
