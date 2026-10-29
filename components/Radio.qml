import QtQuick
import qs.theme

/*
 * Single-choice row. The ring fills from the centre rather than swapping glyph,
 * so selection moving down a list reads as one continuous change.
 */
Item {
    id: root

    property bool checked: false
    property string text: ""

    signal clicked

    implicitWidth: ring.width + Theme.space(2) + label.implicitWidth
    implicitHeight: Math.max(16, label.implicitHeight)

    Rectangle {
        id: ring

        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: root.checked ? Theme.fg : (hover.containsMouse ? Theme.fgDim : Theme.lineHi)

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.standard
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: root.checked ? 7 : 0
            height: width
            radius: height / 2
            color: Theme.fg

            Behavior on width {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.expressive
                }
            }
        }
    }

    Text {
        id: label

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: ring.right
        anchors.leftMargin: Theme.space(2)
        anchors.right: parent.right
        text: root.text
        elide: Text.ElideRight
        color: root.checked ? Theme.fg : Theme.fgDim
        font.family: Theme.fontUi
        font.pixelSize: 12
        font.weight: root.checked ? Font.Medium : Font.Normal
        renderType: Text.NativeRendering

        Behavior on color {
            ColorAnimation {
                duration: Theme.standard
            }
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
