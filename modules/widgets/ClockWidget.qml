import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The time in large dot-matrix numerals, with the date beneath.
 *
 * The numerals are as large as the widget allows: sized from a measured copy of
 * the same text, so they fill the width however the font's proportions work out.
 */
Item {
    id: root

    // The width one pixel of numeral size takes, measured rather than assumed.
    DotText {
        id: probe

        visible: false
        text: "16:54"
        size: 100
        plain: true
    }

    readonly property real unit: probe.implicitWidth > 0 ? probe.implicitWidth / 100 : 3.2
    readonly property real numeral: Math.max(24, Math.min(root.height * 0.7, root.width / root.unit))

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.numeral * 0.2)

        DotText {
            text: Time.format("HH:mm")
            size: root.numeral
            plain: true
        }

        SectionLabel {
            leftPadding: 4
            text: `${Time.format("dddd · d MMMM")} · week ${Time.weekNumber()}`
            color: Theme.fgDim
        }
    }
}
