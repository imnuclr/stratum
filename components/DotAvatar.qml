import QtQuick
import qs.theme

/*
 * A picture of someone, as a clean round photo inside a ring of dots.
 *
 * The same treatment the lock screen gives the user's avatar, and for the same
 * reason its comment gives: a face dithered into dots reads muddier than the
 * photo and is genuinely hard to make out at this size. The dots belong around
 * the picture, not in it — the shell keeps its dot vocabulary in the ring while
 * the face stays legible.
 *
 * The photo itself is RoundImage, shared with the album art, so the two cannot
 * drift apart.
 */
Item {
    id: root

    property string source: ""
    // Drawn when there is no picture: a letter if there is a name to take one
    // from, the glyph otherwise.
    property string name: ""
    property string fallbackIcon: "bell"

    property real size: 40
    property real dotSize: 2.4
    property color ringColor: Theme.fgFaint

    readonly property real inset: Math.round(root.size * 0.13)
    readonly property bool hasPhoto: root.source.length > 0

    implicitWidth: root.size
    implicitHeight: root.size

    DotRing {
        anchors.fill: parent
        value: 1
        animated: false
        dotSize: root.dotSize
        onColor: root.ringColor

        Behavior on onColor {
            ColorAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    RoundImage {
        id: photo

        anchors.fill: parent
        anchors.margins: root.inset
        visible: root.hasPhoto
        source: root.source
    }

    Rectangle {
        anchors.fill: photo
        radius: width / 2
        visible: !root.hasPhoto
        color: Theme.surfaceTop

        Text {
            anchors.centerIn: parent
            visible: root.name.length > 0
            text: root.name.charAt(0).toUpperCase()
            color: Theme.fgBright
            font.family: Theme.fontRounded
            font.pixelSize: Math.round(root.size * 0.38)
            font.variableAxes: ({ "wght": 500 })
            renderType: Text.NativeRendering
        }

        DotIcon {
            anchors.centerIn: parent
            visible: root.name.length === 0
            width: Math.round(root.size * 0.5)
            height: Math.round(root.size * 0.5)
            name: root.fallbackIcon
            color: Theme.fgBright
        }
    }
}
