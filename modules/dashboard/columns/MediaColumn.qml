import QtQuick
import qs.components
import qs.services
import qs.theme

Item {
    id: root

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.space(3)

        SectionLabel {
            text: Media.identity.length > 0 ? Media.identity : "media"
        }

        Row {
            spacing: Theme.space(3)

            DotImage {
                width: 104
                height: 104
                // Finer pitch and size-by-brightness: album art is the only
                // photographic thing in the shell, and thresholding it at a 4px
                // grid throws away the picture.
                cell: 3
                dotScale: 0.5
                halftone: true
                circular: true
                source: Media.artUrl
                visible: Media.artUrl.length > 0
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space(1)

                // Title and artist keep their own case. Everything else in the
                // strip is a caps micro-label, but a track name is a name.
                Text {
                    width: 200
                    elide: Text.ElideRight
                    text: Media.available ? Media.title : "Nothing playing"
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                Text {
                    width: 200
                    elide: Text.ElideRight
                    text: Media.artist
                    visible: Media.artist.length > 0
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 15
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.space(2)

        DotBar {
            id: progress

            // A fixed count stops wherever it stops; deriving it from the width
            // means the run spans the column whatever the column is.
            readonly property real pitch: dotSize * 2
            count: Math.max(8, Math.floor((parent.width + dotSize) / pitch))
            dotSize: 5.6
            litScale: 1.15
            value: Media.progress
            visible: Media.length > 0
        }

        Item {
            width: parent.width
            height: elapsed.implicitHeight
            visible: Media.length > 0

            DotText {
                id: elapsed

                anchors.left: parent.left
                text: Media.elapsedLabel
                size: 15
                color: Theme.fgFaint
            }

            DotText {
                anchors.right: parent.right
                text: Media.lengthLabel
                size: 15
                color: Theme.fgFaint
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.space(4)
            visible: Media.available

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "skip-back"
                size: 19
                filled: true
                color: Media.canPrevious ? Theme.fg : Theme.fgFaint

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.previous()
                }
            }

            /*
             * The one filled control on the strip: everything else here is a
             * reading rather than an action. It shares the accent with the dot at
             * the head of the bar, which is the shell's other control — the two
             * are the only places the accent appears, so they match.
             */
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: width / 2
                color: transport.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                    }
                }

                Glyph {
                    anchors.centerIn: parent
                    name: Media.playing ? "pause" : "play"
                    size: 17
                    filled: true
                    color: Theme.bg
                }

                MouseArea {
                    id: transport

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.playPause()
                }
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "skip-forward"
                size: 19
                filled: true
                color: Media.canNext ? Theme.fg : Theme.fgFaint

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.next()
                }
            }
        }
    }
}
