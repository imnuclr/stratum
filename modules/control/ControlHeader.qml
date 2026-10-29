import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Time on the left, the two things you reach for on the right. Settings and
 * power sit here rather than among the toggles because neither is a state — one
 * opens a panel and the other ends the session.
 */
Item {
    id: root

    implicitHeight: 42

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: Theme.space(3)

        DotText {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.format("HH:mm")
            size: 26
            // Changes once a minute, but the cascade on a clock in a panel that
            // is only up for seconds just looks like a glitch.
            plain: true
        }

        SectionLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: Time.format("ddd d MMM")
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        spacing: Theme.space(2)

        Repeater {
            model: [
                { icon: "settings", action: "settings" },
                { icon: "power", action: "session" }
            ]

            Rectangle {
                required property var modelData

                readonly property bool danger: modelData.action === "session"

                width: 40
                height: 40
                radius: width / 2
                color: hover.hovered ? Theme.surfaceTop : Theme.surfaceHi

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                    }
                }

                Glyph {
                    anchors.centerIn: parent
                    name: modelData.icon
                    size: 18
                    color: parent.danger && hover.hovered ? Theme.accent : Theme.fgBright
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Shell.toggle(modelData.action)
                }
            }
        }
    }
}
