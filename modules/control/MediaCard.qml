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
    // Answers the pointer like every other tile in the shell does. Nothing here
    // said it could be interacted with at all until it was clicked.
    color: cardHover.hovered ? Theme.surfaceTop : Theme.surfaceHi

    Behavior on color {
        ColorAnimation {
            duration: Theme.micro
        }
    }

    HoverHandler {
        id: cardHover
    }

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
                color: !Media.canPrevious
                    ? Theme.fgFaint
                    : (prevHover.hovered ? Theme.fg : Theme.fgBright)
                scale: prevTap.pressed ? 0.86 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.gentle
                    }
                }

                HoverHandler {
                    id: prevHover

                    enabled: Media.canPrevious
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: prevTap

                    onTapped: Media.previous()
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 44
                radius: width / 2
                color: Theme.accent
                // The one red thing on the panel, so it carries the clearest
                // response: lifts under the pointer, gives when held.
                scale: playTap.pressed ? 0.9 : (playHover.hovered ? 1.07 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.gentle
                    }
                }

                Glyph {
                    anchors.centerIn: parent
                    name: Media.playing ? "pause" : "play"
                    size: 16
                    filled: true
                    color: Theme.bg
                }

                HoverHandler {
                    id: playHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: playTap

                    onTapped: Media.playPause()
                }
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "skip-forward"
                size: 15
                filled: true
                color: !Media.canNext
                    ? Theme.fgFaint
                    : (nextHover.hovered ? Theme.fg : Theme.fgBright)
                scale: nextTap.pressed ? 0.86 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.gentle
                    }
                }

                HoverHandler {
                    id: nextHover

                    enabled: Media.canNext
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: nextTap

                    onTapped: Media.next()
                }
            }
        }
    }
}
