import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * What is playing: the disc, the track, how far through it is, and the buttons.
 *
 * The buttons are a reading — widgets on the desktop do not take the pointer, so
 * these show what is available and the keys and the control centre are where it
 * is changed.
 */
Item {
    id: root

    readonly property real disc: root.height - Theme.space(4) * 2

    Component.onCompleted: Media.watch()
    Component.onDestruction: Media.unwatch()

    Row {
        anchors.fill: parent
        anchors.margins: Theme.space(4)
        spacing: Theme.space(5)

        SpinningArt {
            anchors.verticalCenter: parent.verticalCenter
            size: root.disc
            cell: Math.max(2.5, root.disc / 56)
            source: Media.artUrl
            colored: false
            visible: Media.artUrl.length > 0
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (Media.artUrl.length > 0 ? root.disc + Theme.space(5) : 0)
            spacing: Theme.space(1)

            SectionLabel {
                width: parent.width
                elide: Text.ElideRight
                text: Media.available ? `now playing · ${Media.identity}` : "now playing"
                color: Theme.fgDim
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.available ? Media.title : "Nothing playing"
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Math.max(18, root.height * 0.13)
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
                font.pixelSize: Math.max(12, root.height * 0.075)
                renderType: Text.NativeRendering
            }

            DotBar {
                topPadding: Theme.space(2)
                count: Math.max(8, Math.floor((parent.width + dotSize) / (dotSize * 2)))
                dotSize: 2.6
                value: Media.progress
                visible: Media.length > 0
            }

            Row {
                topPadding: Theme.space(2)
                spacing: Theme.space(4)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "skip-back"
                    size: 15
                    filled: true
                    color: Media.canPrevious ? Theme.fgBright : Theme.fgFaint
                }

                Rectangle {
                    width: Math.max(36, root.height * 0.24)
                    height: width
                    radius: width / 2
                    color: Theme.accent

                    Glyph {
                        anchors.centerIn: parent
                        name: Media.playing ? "pause" : "play"
                        size: parent.width * 0.38
                        filled: true
                        color: "#FFFFFF"
                    }
                }

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "skip-forward"
                    size: 15
                    filled: true
                    color: Media.canNext ? Theme.fgBright : Theme.fgFaint
                }
            }
        }
    }
}
