import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

/*
 * What is playing: the disc, the track, how far through it is, and the buttons.
 *
 * The buttons work: the canvas takes the pointer over its widgets (and nowhere
 * else), so these are real controls. When the player gives no cover — a browser
 * tab often does not — a dotted ring stands in its place so the card keeps its
 * shape.
 */
Item {
    id: root

    property var item: ({})
    property bool live: true

    readonly property string cover: Widgets.option(root.item, "art")
    readonly property real disc: root.height - Theme.space(4) * 2
    readonly property bool hasArt: Media.artUrl.length > 0

    Watch {
        service: Media
        live: root.live
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.space(4)
        spacing: Theme.space(5)

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: root.disc
            height: root.disc

            SpinningArt {
                anchors.fill: parent
                size: root.disc
                cell: Math.max(2.5, root.disc / 56)
                source: Media.artUrl
                colored: root.cover === "colour"
                visible: root.hasArt && root.cover !== "plain"
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.surfaceHi
                visible: root.hasArt && root.cover === "plain"

                Image {
                    anchors.fill: parent
                    source: root.hasArt && root.cover === "plain" ? Media.artUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 400
                    asynchronous: true
                }
            }

            // No cover: a ring and a pair of headphones, so the card keeps its shape.
            DotRing {
                anchors.fill: parent
                visible: !root.hasArt
                count: 40
                dotSize: Math.max(2, root.disc / 40)
                value: 1
                onColor: Theme.dotOff
                animated: false

                Glyph {
                    anchors.centerIn: parent
                    name: "headphones"
                    size: root.disc * 0.26
                    color: Theme.fgDim
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - root.disc - Theme.space(5)
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
                font.pixelSize: Math.max(18, root.height * 0.12)
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
                font.pixelSize: Math.max(12, root.height * 0.07)
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

                MediaButton {
                    icon: "skip-back"
                    enabled: Media.canPrevious
                    onClicked: Media.previous()
                }

                // The one coloured control, as on the other media cards.
                Rectangle {
                    width: Math.max(36, root.height * 0.22)
                    height: width
                    radius: width / 2
                    color: Theme.accent
                    scale: playTap.pressed ? 0.9 : (playHover.hovered ? 1.06 : 1)

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
                        size: parent.width * 0.38
                        filled: true
                        color: Theme.bg
                    }

                    HoverHandler {
                        id: playHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        id: playTap

                        enabled: !Widgets.editing
                        onTapped: Media.playPause()
                    }
                }

                MediaButton {
                    icon: "skip-forward"
                    enabled: Media.canNext
                    onClicked: Media.next()
                }
            }
        }
    }

    component MediaButton: Item {
        id: button

        property string icon: ""
        property bool enabled: true

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 28

        Glyph {
            anchors.centerIn: parent
            name: button.icon
            size: 15
            filled: true
            color: !button.enabled ? Theme.fgFaint : (hover.hovered ? Theme.fg : Theme.fgBright)
        }

        HoverHandler {
            id: hover

            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: button.enabled && !Widgets.editing
            onTapped: button.clicked()
        }
    }
}
