import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The time in large dot-matrix numerals, with the date beneath.
 */
Item {
    id: root

    // Sized from the room it has, so resizing the widget resizes the clock.
    readonly property real numeral: Math.max(24, Math.min(root.height * 0.66, root.width / 5.2))

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.numeral * 0.16)

        DotText {
            text: Time.format("HH:mm")
            size: root.numeral
            plain: true
        }

        SectionLabel {
            text: `${Time.format("dddd · d MMMM")} · week ${Time.weekNumber()}`
            color: Theme.fgBright
        }
    }
}
