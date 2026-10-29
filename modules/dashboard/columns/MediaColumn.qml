import QtQuick
import qs.components
import qs.services
import qs.theme

Column {
    id: root

    spacing: Theme.space(2)

    Row {
        spacing: Theme.space(3)

        DotImage {
            width: 104
            height: 104
            cell: 4
            source: Media.artUrl
            visible: Media.artUrl.length > 0
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(1)

            Text {
                width: 220
                elide: Text.ElideRight
                text: Media.available ? Media.title : "Nothing playing"
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            SectionLabel {
                width: 220
                elide: Text.ElideRight
                dim: true
                text: Media.artist
                visible: Media.artist.length > 0
            }

            DotBar {
                count: 24
                value: Media.progress
                visible: Media.length > 0
            }

            SectionLabel {
                dim: true
                text: Media.identity
                visible: Media.identity.length > 0
            }
        }
    }
}
