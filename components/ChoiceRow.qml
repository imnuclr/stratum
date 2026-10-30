import QtQuick
import qs.theme

/*
 * One thing in a list you can pick: a device, a network, an output. Its icon,
 * its name and a line under it, and what clicking would do on the right. The
 * one in use is marked with a filled ring, as radios are elsewhere.
 */
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string sub: ""
    property string trailing: ""
    property bool chosen: false
    property bool busy: false
    property bool divider: true

    signal clicked
    signal trailingClicked

    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 2
        anchors.bottomMargin: 2
        anchors.leftMargin: -Theme.space(2)
        anchors.rightMargin: -Theme.space(2)
        radius: Theme.rInner
        color: hover.hovered ? Theme.surfaceTop : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.micro
            }
        }
    }

    Glyph {
        id: glyph

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.icon.length > 0
        name: root.icon
        size: 18
        color: root.chosen ? Theme.fg : Theme.fgDim
    }

    Column {
        anchors.left: glyph.visible ? glyph.right : parent.left
        anchors.leftMargin: glyph.visible ? Theme.space(3) : 0
        anchors.right: tail.left
        anchors.rightMargin: Theme.space(3)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 14
            font.weight: root.chosen ? Font.Medium : Font.Normal
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            visible: root.sub.length > 0
            elide: Text.ElideRight
            text: root.sub
            color: Theme.fgDim
            font.family: Theme.fontUi
            font.pixelSize: 12
            renderType: Text.NativeRendering
        }
    }

    Row {
        id: tail

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space(3)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.trailing.length > 0
            text: root.busy ? "…" : root.trailing
            color: trailHover.hovered ? Theme.fg : Theme.fgDim
            font.family: Theme.fontUi
            font.pixelSize: 12
            font.weight: Font.Medium
            renderType: Text.NativeRendering

            HoverHandler {
                id: trailHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.trailingClicked()
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: 8
            color: "transparent"
            border.width: 1
            border.color: root.chosen ? Theme.fg : Theme.lineHi

            Rectangle {
                anchors.centerIn: parent
                width: root.chosen ? 8 : 0
                height: width
                radius: width / 2
                color: Theme.fg

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.standard
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.line
        visible: root.divider
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.clicked()
    }
}
