import QtQuick
import qs.theme

/*
 * A compact pill for actions sitting inside a row of content.
 *
 * LinkButton is the same idea at the size a settings row wants: 32px tall with
 * 24px of padding either side. Three of those inside a notification ran off the
 * edge of the panel and wrapped, which is how a tidy row of buttons turns into a
 * stray one on a line of its own. This is the same shape with the padding a
 * dense context can afford, and still a real target rather than a word.
 *
 * `secondary` marks an action the shell is offering rather than one the sender
 * asked for. Those should not look like peers of the app's own buttons — the
 * hairline says it is available without claiming to be the thing to do.
 */
Rectangle {
    id: root

    property string text: ""
    property bool secondary: false

    signal clicked

    implicitWidth: label.implicitWidth + Theme.space(3) * 2
    implicitHeight: 30
    radius: height / 2

    color: {
        if (root.secondary)
            return hover.hovered ? Theme.surfaceTop : "transparent";
        return hover.hovered ? Theme.fg : Theme.surfaceTop;
    }

    border.width: root.secondary ? 1 : 0
    border.color: hover.hovered ? Theme.lineHi : Theme.line

    Behavior on color {
        ColorAnimation {
            duration: Theme.micro
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.smooth
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.micro
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.smooth
        }
    }

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        // Inverted fill on a primary press, the way every other state in the
        // shell reads; the secondary one only ever brightens.
        color: root.secondary
            ? (hover.hovered ? Theme.fg : Theme.fgBright)
            : (hover.hovered ? Theme.bg : Theme.fg)
        font.family: Theme.fontUi
        font.pixelSize: 13
        font.weight: Font.Medium
        renderType: Text.NativeRendering

        Behavior on color {
            ColorAnimation {
                duration: Theme.micro
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
