import QtQuick
import qs.services
import qs.theme

/*
 * Power profiles as one segmented control. The active segment is a filled pill
 * with dark content, matching how the sliders show their filled range — a thing
 * that is "on" in this shell is white and inverted, not outlined.
 */
Row {
    id: root

    readonly property var labels: ({
        "power-saver": "eco",
        "balanced": "bal",
        "performance": "max",
        "quiet": "ult"
    })

    spacing: 0

    Repeater {
        model: Power.profiles

        Item {
            id: segment

            required property var modelData
            required property int index

            readonly property bool active: Power.profile === modelData

            width: root.width / Power.profiles.length
            height: 54

            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: height / 2
                color: segment.active ? Theme.fg : (hover.hovered ? Theme.surfaceTop : "transparent")

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.standard
                    }
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.space(2)

                ProfileGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 18
                    count: Power.profiles.length
                    level: segment.index + 1
                    color: segment.active ? Theme.bg : Theme.fgBright
                    dimColor: segment.active ? Qt.alpha(Theme.bg, 0.3) : Qt.alpha(Theme.fgFaint, 0.5)
                }

                SectionLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.labels[segment.modelData] ?? segment.modelData
                    color: segment.active ? Theme.bg : Theme.fgBright
                }
            }

            HoverHandler {
                id: hover
            }

            TapHandler {
                onTapped: Power.setProfile(segment.modelData)
            }
        }
    }
}
