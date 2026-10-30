import QtQuick
import qs.theme

/*
 * The top of a settings page: its icon on a tile, its name, and one line on
 * what lives here.
 */
Item {
    id: root

    property string icon: "settings"
    property string title: ""
    property string detail: ""

    implicitHeight: 76

    Rectangle {
        id: tile

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 60
        height: 60
        radius: 18
        color: Theme.surfaceTop
        border.width: 1
        border.color: Theme.lineHi

        DotIcon {
            anchors.centerIn: parent
            width: 34
            height: 34
            name: root.icon
            color: Theme.fg
        }
    }

    Column {
        anchors.left: tile.right
        anchors.leftMargin: Theme.space(4)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            text: root.title
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 24
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            visible: root.detail.length > 0
            text: root.detail
            color: Theme.fgDim
            font.family: Theme.fontUi
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }
}
