import QtQuick
import qs.theme

/*
 * A compact pill button for the right-hand side of a setting row.
 */
Rectangle {
    id: root

    property string text: ""
    property string icon: ""
    property bool danger: false

    signal clicked

    implicitWidth: row.implicitWidth + Theme.space(4) * 2
    implicitHeight: 32
    radius: height / 2
    color: hover.hovered ? (root.danger ? Theme.accent : Theme.fg) : Theme.surfaceTop

    Behavior on color {
        ColorAnimation {
            duration: Theme.micro
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Theme.space(1)

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.icon.length > 0
            name: root.icon
            size: 14
            color: hover.hovered ? Theme.bg : Theme.fg
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: hover.hovered ? Theme.bg : Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 13
            font.weight: Font.Medium
            renderType: Text.NativeRendering
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
