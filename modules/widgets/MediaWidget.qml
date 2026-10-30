import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * What is playing: the disc, the track, how far through it is.
 *
 * A reading, not a control — widgets on the desktop do not take the pointer, so
 * the play button here shows the state and the keys and the control centre are
 * where it is changed.
 */
Item {
    id: root

    Component.onCompleted: Media.watch()
    Component.onDestruction: Media.unwatch()

    Row {
        anchors.fill: parent
        anchors.margins: Theme.space(4)
        spacing: Theme.space(4)

        SpinningArt {
            anchors.verticalCenter: parent.verticalCenter
            size: Math.min(root.height - Theme.space(4) * 2, 96)
            source: Media.artUrl
            visible: Media.artUrl.length > 0
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (Media.artUrl.length > 0 ? Math.min(root.height - Theme.space(4) * 2, 96) + Theme.space(4) : 0)
            spacing: Theme.space(1)

            SectionLabel {
                width: parent.width
                elide: Text.ElideRight
                text: Media.available ? `now playing · ${Media.identity}` : "now playing"
                color: Theme.fgBright
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.available ? Media.title : "Nothing playing"
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 20
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.artist
                visible: text.length > 0
                color: Theme.fgDim
                font.family: Theme.fontUi
                font.pixelSize: 14
                renderType: Text.NativeRendering
            }

            DotBar {
                topPadding: Theme.space(1)
                count: Math.max(8, Math.floor((parent.width + dotSize) / (dotSize * 2)))
                dotSize: 3
                value: Media.progress
                visible: Media.length > 0
            }

            Rectangle {
                width: 30
                height: 30
                radius: 15
                color: Theme.accent

                Glyph {
                    anchors.centerIn: parent
                    name: Media.playing ? "pause" : "play"
                    size: 12
                    filled: true
                    color: Theme.bg
                }
            }
        }
    }
}
