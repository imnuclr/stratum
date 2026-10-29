import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The ring reads temperature against a fixed -10..40°C span rather than against
 * anything measured, so the same reading always fills it the same amount.
 */
Column {
    id: root

    readonly property real span: Weather.metric ? 50 : 90
    readonly property real floor: Weather.metric ? -10 : 14

    spacing: Theme.space(2)

    Row {
        spacing: Theme.space(3)

        DotRing {
            width: 74
            height: 74
            count: 40
            dotSize: 3.2
            value: Weather.ready
                ? Math.max(0, Math.min(1, (Weather.temperature - root.floor) / root.span))
                : 0

            DotText {
                anchors.centerIn: parent
                text: Weather.ready ? `${Math.round(Weather.temperature)}` : "--"
                size: 17
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(1)

            SectionLabel {
                text: Weather.condition.length > 0 ? Weather.condition : (Weather.error.length > 0 ? Weather.error : "loading")
            }

            SectionLabel {
                dim: true
                text: Weather.place.length > 0 ? Weather.place : "—"
            }

            SectionLabel {
                dim: true
                visible: Weather.ready
                text: `feels ${Math.round(Weather.apparent)}°${Weather.unit} · ${Math.round(Weather.humidity)}%`
            }
        }
    }
}
