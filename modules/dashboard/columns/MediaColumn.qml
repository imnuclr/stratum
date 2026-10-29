import QtQuick
import qs.components
import qs.services
import qs.theme

Column {
    id: root

    readonly property real textWidth: 190

    spacing: Theme.space(2)

    SectionLabel {
        text: Media.identity.length > 0 ? Media.identity : "media"
    }

    Row {
        spacing: Theme.space(3)

        DotImage {
            width: 108
            height: 108
            cell: 4
            source: Media.artUrl
            visible: Media.artUrl.length > 0
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(1)

            // Title and artist stay in their own case. Everything else in the
            // strip is a caps micro-label, but a track name is a name.
            Text {
                width: root.textWidth
                elide: Text.ElideRight
                text: Media.available ? Media.title : "Nothing playing"
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 19
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            Text {
                width: root.textWidth
                elide: Text.ElideRight
                text: Media.artist
                visible: Media.artist.length > 0
                color: Theme.fgDim
                font.family: Theme.fontUi
                font.pixelSize: 14
                renderType: Text.NativeRendering
            }

            Item {
                width: root.textWidth
                height: Theme.space(2)
            }

            DotBar {
                count: 26
                value: Media.progress
                visible: Media.length > 0
            }

            Item {
                width: root.textWidth
                height: elapsed.implicitHeight
                visible: Media.length > 0

                DotText {
                    id: elapsed

                    anchors.left: parent.left
                    text: Media.elapsedLabel
                    size: 14
                    color: Theme.fgFaint
                }

                DotText {
                    anchors.right: parent.right
                    text: Media.lengthLabel
                    size: 14
                    color: Theme.fgFaint
                }
            }
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.space(3)
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
         * The one red thing on the strip. The accent marks the single primary
         * action in a view; everything else here is a reading, not an action.
         */
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 38
            height: 38
            radius: width / 2
            color: Theme.accent

            Glyph {
                anchors.centerIn: parent
                name: Media.playing ? "pause" : "play"
                size: 16
                filled: true
                color: Theme.bg
            }

            MouseArea {
                anchors.fill: parent
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
