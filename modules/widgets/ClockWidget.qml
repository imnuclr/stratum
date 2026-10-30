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

    property var item: ({})
    property bool live: true

    readonly property bool twelve: Widgets.option(root.item, "hours") === "12h"
    readonly property bool showDate: Widgets.option(root.item, "date") !== "hide"
    readonly property string pattern: root.twelve ? "h:mm" : "HH:mm"

    // The width one pixel of numeral size takes, measured rather than assumed.
    DotText {
        id: probe

        visible: false
        text: root.twelve ? "12:54" : "16:54"
        size: 100
        plain: true
    }

    readonly property real unit: probe.implicitWidth > 0 ? probe.implicitWidth / 100 : 3.2
    readonly property real numeral: Math.max(24, Math.min(root.height * (root.showDate ? 0.7 : 0.9), root.width / root.unit))

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.numeral * 0.08)

        DotText {
            text: Time.format(root.pattern)
            size: root.numeral
            plain: true
        }

        // Sized to the numerals and set in from their left edge by the same
        // margin the first digit has, so it reads as the clock's own caption
        // rather than a label left lying underneath it.
        Text {
            visible: root.showDate
            leftPadding: root.numeral * 0.06
            text: `${Time.format("dddd · d MMMM")} · week ${Time.weekNumber()}`.toUpperCase()
            color: Theme.fgBright
            font.family: Theme.fontUi
            font.pixelSize: Math.max(11, root.numeral * 0.06)
            font.weight: Font.Medium
            font.letterSpacing: Math.max(1.4, root.numeral * 0.012)
            renderType: Text.NativeRendering
        }
    }
}
