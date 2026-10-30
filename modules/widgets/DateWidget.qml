import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The month, the day as a large numeral, and the week with today marked.
 */
Item {
    id: root

    // Monday first.
    readonly property int today: (Time.now.getDay() + 6) % 7

    SectionLabel {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.space(4)
        text: Time.format("MMMM")
        color: Theme.fgBright
    }

    DotText {
        anchors.centerIn: parent
        text: Time.format("d")
        size: Math.max(24, root.height * 0.32)
        plain: true
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space(4)
        spacing: Math.max(Theme.space(2), (root.width - Theme.space(4) * 2 - 7 * 8) / 6 - 6)

        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]

            Column {
                required property string modelData
                required property int index

                spacing: 2

                SectionLabel {
                    text: parent.modelData
                    color: parent.index === root.today ? Theme.fg : Theme.fgDim
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 8
                    height: 1.5
                    color: Theme.fg
                    visible: parent.index === root.today
                }
            }
        }
    }
}
