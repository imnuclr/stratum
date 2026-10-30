import QtQuick
import qs.theme

/*
 * A level as a filled pill: the fill is the reading, and it carries the icon
 * with it. The track beyond the fill is dotted rather than empty, so the
 * remaining range is still legible as a scale.
 *
 * The value label inverts where the fill reaches it — on a dark pill over the
 * fill, plain over the track. Without that it disappears into the white at the
 * top of the range.
 */
Item {
    id: root

    property real value: 0
    property string icon: ""
    property string label: ""
    property bool enabled: true

    // How far one notch of the scroll wheel moves it.
    property real wheelStep: 0.02

    signal moved(real value)

    readonly property real fillWidth: Math.max(height, height + (width - height) * Math.max(0, Math.min(1, value)))
    readonly property bool covered: fillWidth > width - Theme.space(3) - number.implicitWidth - Theme.space(3)

    implicitHeight: 56

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceHi
    }

    // Dotted remainder, clipped to the track so it never spills past the ends.
    Item {
        anchors.fill: parent
        anchors.leftMargin: root.height
        anchors.rightMargin: Theme.space(3)
        clip: true

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Repeater {
                model: Math.max(0, Math.floor(parent.parent.width / 9))

                Rectangle {
                    required property int index

                    width: 3.4
                    height: 3.4
                    radius: 1.7
                    color: Theme.dotOff
                    // Hidden under the fill rather than recoloured: the fill is
                    // opaque, and a dot showing through would read as a gap.
                    visible: root.height + index * 9 > root.fillWidth
                }
            }
        }
    }

    Rectangle {
        id: fill

        width: root.fillWidth
        height: parent.height
        radius: height / 2
        color: root.enabled ? Theme.fg : Theme.fgFaint

        Behavior on width {
            NumberAnimation {
                duration: Theme.micro
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: (root.height - 22) / 2
            name: root.icon
            size: 22
            stroke: 2
            color: Theme.bg
        }
    }

    Item {
        id: labelBox

        anchors.right: parent.right
        anchors.rightMargin: Theme.space(3)
        anchors.verticalCenter: parent.verticalCenter
        width: number.implicitWidth + (root.covered ? Theme.space(4) : 0)
        height: number.implicitHeight + (root.covered ? Theme.space(2) : 0)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.bg
            visible: root.covered
        }

        DotText {
            id: number

            anchors.centerIn: parent
            text: root.label
            size: 19
            color: Theme.fg
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // The fill starts a full height in so the icon fits, so the usable track
        // is narrower than the control and the mapping has to account for it.
        onPositionChanged: event => {
            if (pressed)
                root.moved(Math.max(0, Math.min(1, (event.x - root.height / 2) / (root.width - root.height))));
        }
        onPressed: event => root.moved(Math.max(0, Math.min(1, (event.x - root.height / 2) / (root.width - root.height))))

        // A notch of the wheel is a step; a touchpad's smooth scroll adds up
        // to the same, so a flick across it does not jump the whole way.
        onWheel: event => {
            const notches = event.angleDelta.y !== 0 ? event.angleDelta.y / 120 : event.pixelDelta.y / 40;
            if (notches !== 0)
                root.moved(Math.max(0, Math.min(1, root.value + notches * root.wheelStep)));
        }
    }
}
