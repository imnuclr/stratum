import QtQuick
import qs.services
import qs.theme

/*
 * Album art as a disc: a ring around the dithered picture, turning while
 * something is playing and holding still where it stopped when it is paused —
 * the way a record would, not snapping back to upright.
 *
 * The ring is what makes it read as an object rather than a crop, and what makes
 * the turning visible at all: a round picture of mostly-random dots spun on its
 * own looks like it has barely moved.
 */
Item {
    id: root

    property string source: ""
    property real size: 64
    property real cell: 3
    property real dotScale: 0.5
    property bool colored: true

    implicitWidth: size
    implicitHeight: size

    Item {
        id: disc

        anchors.fill: parent

        // Paused rather than stopped, so it resumes from the angle it held.
        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: 9000
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
                }
            }
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
            visible: root.source.length > 0
        }
    }

    // Outside the turning disc: a spinning pair of headphones only looks broken.
    NoCover {
        anchors.centerIn: parent
        width: root.size - 10
        height: width
        visible: root.source.length === 0
    }

}
