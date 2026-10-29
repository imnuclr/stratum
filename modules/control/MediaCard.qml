import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Now playing, as a card set into the stack: it is the one block in the control
 * centre that is mostly a reading rather than a control.
 */
Rectangle {
    id: root

    implicitHeight: 88

    radius: Theme.rTile
    color: Theme.surfaceHi

    Row {
        anchors.fill: parent
        anchors.margins: Theme.space(2)
        spacing: Theme.space(3)

        DotImage {
            anchors.verticalCenter: parent.verticalCenter
            width: 64
            height: 64
            cell: 3
            dotScale: 0.5
            halftone: true
            circular: true
            source: Media.artUrl
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 64 - 128 - Theme.space(3) * 2
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.title
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 15
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.artist
                color: Theme.fgDim
                font.family: Theme.fontUi
                font.pixelSize: 13
                renderType: Text.NativeRendering
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(2)

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "skip-back"
                size: 15
                filled: true
                color: Media.canPrevious ? Theme.fgBright : Theme.fgFaint

                TapHandler {
                    onTapped: Media.previous()
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: width / 2
                color: Theme.accent

                Glyph {
                    anchors.centerIn: parent
                    name: Media.playing ? "pause" : "play"
                    size: 16
                    filled: true
                    color: Theme.bg
                }

                TapHandler {
                    onTapped: Media.playPause()
                }
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "skip-forward"
                size: 15
                filled: true
                color: Media.canNext ? Theme.fgBright : Theme.fgFaint

                TapHandler {
                    onTapped: Media.next()
                }
            }
        }
    }
}
