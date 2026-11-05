import QtQuick
import qs.services
import qs.theme

/*
 * Album art as a disc: a ring around the sleeve, turning while something is
 * playing and holding still where it stopped when it is paused — the way a
 * record would, not snapping back to upright.
 *
 * The ring is what makes it read as an object rather than a crop, and what makes
 * the turning visible at all: a round picture spun on its own looks like it has
 * barely moved.
 *
 * The sleeve is the photograph, not a dither of it. Album art is the one image
 * on screen chosen to be looked at, and dithering a face or a cover into dots
 * costs exactly the detail that makes it recognisable — the same reason the lock
 * screen stopped doing it to the user's avatar. `dithered` keeps the old
 * treatment for anyone who wants the dots.
 */
Item {
    id: root

    property string source: ""
    property real size: 64
    property real cell: 3
    property real dotScale: 0.5
    property bool colored: true
    property bool dithered: false

    implicitWidth: size
    implicitHeight: size

    Item {
        id: disc

        anchors.fill: parent

        // Paused rather than stopped, so it resumes from the angle it held.
        NumberAnimation on rotation {
            from: 0
            to: 360
            // A slow turn, like a record seen from across the room: fast enough
            // to show it is playing, slow enough not to pull the eye.
            duration: 24000
            loops: Animation.Infinite
            running: true
            paused: !Media.playing
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: Media.playing ? Theme.fgBright : Theme.fgFaint

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }
        }

        RoundImage {
            anchors.centerIn: parent
            width: root.size - 10
            height: root.size - 10
            source: root.source
            visible: root.source.length > 0 && !root.dithered
        }

        DotImage {
            anchors.centerIn: parent
            width: root.size - 10
            height: root.size - 10
            cell: root.cell
            dotScale: root.dotScale
            halftone: true
            colored: root.colored
            circular: true
            source: root.source
            visible: root.source.length > 0 && root.dithered
        }

        NoCover {
            anchors.centerIn: parent
            width: root.size - 10
            height: width
            visible: root.source.length === 0
        }
    }

}
