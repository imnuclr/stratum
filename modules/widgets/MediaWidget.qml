import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * What is playing, laid out like a record sleeve: the cover as a large dithered
 * disc on the left, and on the right the source in dot-matrix capitals, the
 * title, the artist, a dotted line of how far through, and the controls.
 *
 * The controls are real: the canvas takes the pointer over its widgets. When the
 * player sends no cover — a browser tab often does not — a dotted ring holds the
 * disc's place so the card keeps its shape.
 */
Item {
    id: root

    property var item: ({})
    property bool live: true

    readonly property string cover: Widgets.option(root.item, "art")
    readonly property real pad: root.height * 0.12
    readonly property real disc: root.height - root.pad * 2
    readonly property bool hasArt: Media.artUrl.length > 0

    Watch {
        service: Media
        live: root.live
    }

    Item {
        id: art

        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        width: root.disc
        height: root.disc

        DotImage {
            anchors.fill: parent
            visible: root.hasArt
            source: Media.artUrl
            cell: Math.max(3, root.disc / 38)
            dotScale: 0.46
            halftone: true
            circular: true
            colored: root.cover === "colour"
        }

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
                size: root.disc * 0.24
                color: Theme.fgDim
            }
        }
    }

    Column {
        anchors.left: art.right
        anchors.leftMargin: root.pad * 1.1
        anchors.right: parent.right
        anchors.rightMargin: root.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.height * 0.035

        // Where it is coming from, in the dot-matrix face.
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: (Media.available ? `now playing · ${Media.identity}` : "now playing").toUpperCase()
            color: Theme.fgDim
            font.family: Theme.fontDot
            font.pixelSize: Math.max(11, root.height * 0.058)
            font.weight: Font.Bold
            font.letterSpacing: Math.max(1.5, root.height * 0.008)
            font.variableAxes: ({ "ROND": 100 })
            renderType: Text.NativeRendering
        }

        Column {
            width: parent.width
            topPadding: root.height * 0.02
            spacing: root.height * 0.012

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Media.available ? Media.title : "Nothing playing"
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Math.max(18, root.height * 0.11)
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
                font.pixelSize: Math.max(12, root.height * 0.064)
                renderType: Text.NativeRendering
            }
        }

        DotBar {
            topPadding: root.height * 0.03
            count: Math.max(8, Math.floor((parent.width + dotSize) / (dotSize * 2.4)))
            dotSize: Math.max(2.2, root.height * 0.014)
            spacing: dotSize * 1.4
            litScale: 1.3
            value: Media.progress
        }

        Row {
            topPadding: root.height * 0.03
            spacing: root.height * 0.07

            MediaButton {
                icon: "skip-back"
                available: Media.canPrevious
                onClicked: Media.previous()
            }

            // The one coloured control.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(36, root.height * 0.17)
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
                    size: parent.width * 0.36
                    filled: true
                    color: "#FFFFFF"
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
                available: Media.canNext
                onClicked: Media.next()
            }
        }
    }

    component MediaButton: Item {
        id: button

        property string icon: ""
        property bool available: true

        signal clicked

        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(26, root.height * 0.1)
        height: width

        Glyph {
            anchors.centerIn: parent
            name: button.icon
            size: Math.max(14, root.height * 0.06)
            filled: true
            color: !button.available ? Theme.fgFaint : (hover.hovered ? Theme.fg : Theme.fgBright)
        }

        HoverHandler {
            id: hover

            enabled: button.available
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: button.available && !Widgets.editing
            onTapped: button.clicked()
        }
    }
}
