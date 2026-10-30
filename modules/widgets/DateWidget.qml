import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The month at the top, the day as a large numeral under it, and the week along
 * the bottom with today underlined. Everything aligned to the left edge.
 */
Item {
    id: root

    property var item: ({})
    property bool live: true

    readonly property real unit: Math.min(root.width, root.height)
    readonly property real inset: root.unit * 0.13
    // Monday first.
    readonly property int today: (Time.now.getDay() + 6) % 7

    SectionLabel {
        id: month

        x: root.inset
        y: root.inset
        text: Time.format("MMMM")
        color: Theme.fgDim
        font.pixelSize: Math.max(10, root.unit * 0.05)
    }

    DotText {
        x: root.inset - root.unit * 0.01
        anchors.top: month.bottom
        anchors.topMargin: root.unit * 0.06
        text: Time.format("d")
        size: root.unit * 0.42
        plain: true
    }

    Row {
        id: week

        x: root.inset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.inset
        width: root.width - root.inset * 2
        spacing: (week.width - 7 * root.unit * 0.04) / 6

        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]

            Column {
                required property string modelData
                required property int index

                width: root.unit * 0.04
                spacing: root.unit * 0.02

                SectionLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: parent.modelData
                    color: parent.index === root.today ? Theme.fg : Theme.fgFaint
                    font.pixelSize: Math.max(9, root.unit * 0.042)
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.unit * 0.055
                    height: Math.max(1.5, root.unit * 0.008)
                    color: Theme.fg
                    opacity: parent.index === root.today ? 1 : 0
                }
            }
        }
    }
}
