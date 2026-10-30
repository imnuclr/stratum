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
        anchors.margins: Theme.space(5)
        text: Time.format("MMMM")
        color: Theme.fgDim
    }

    DotText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -root.height * 0.02
        text: Time.format("d")
        size: Math.min(root.width, root.height) * 0.36
        plain: true
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space(5)
        spacing: Math.max(Theme.space(2), (root.width - Theme.space(5) * 2 - 7 * 8) / 6 - 6)

        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]

            Column {
                required property string modelData
                required property int index

                spacing: 2

                SectionLabel {
                    text: parent.modelData
                    color: parent.index === root.today ? Theme.fg : Theme.fgFaint
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 8
                    height: 1.5
                    color: Theme.fg
                    opacity: parent.index === root.today ? 1 : 0
                }
            }
        }
    }
}
