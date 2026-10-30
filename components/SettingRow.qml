import QtQuick
import qs.theme

/*
 * One setting: what it is and what it does on the left, its control on the right.
 * The detail line is for the consequence, not a restatement of the title — if it
 * would only repeat the title it should be left empty.
 */
Item {
    id: root

    property string title: ""
    property string detail: ""
    default property alias control: slot.data

    implicitHeight: Math.max(52, copy.implicitHeight + Theme.space(3) * 2)

    Column {
        id: copy

        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: Theme.space(4)
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 14
            font.weight: Font.Medium
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            visible: root.detail.length > 0
            text: root.detail
            color: Theme.fgDim
            font.family: Theme.fontUi
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }

    Item {
        id: slot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.line
    }
}
