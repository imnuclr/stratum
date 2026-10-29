import QtQuick
import qs.theme

/*
 * A round quick toggle with its name beneath. Filled white when on, the same
 * inversion the sliders and the profile control use — "on" in this shell is
 * always a filled shape, never an outlined one.
 */
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool active: false
    property bool available: true

    signal toggled

    implicitWidth: 64
    implicitHeight: circle.height + caption.implicitHeight + Theme.space(2)

    Rectangle {
        id: circle

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 54
        height: 54
        radius: width / 2
        color: root.active ? Theme.fg : (hover.hovered && root.available ? Theme.surfaceTop : Theme.surfaceHi)
        opacity: root.available ? 1 : 0.45

        Behavior on color {
            ColorAnimation {
                duration: Theme.standard
            }
        }

        Glyph {
            anchors.centerIn: parent
            name: root.icon
            size: 21
            stroke: 1.8
            color: root.active ? Theme.bg : Theme.fgBright
        }
    }

    SectionLabel {
        id: caption

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.label
        color: root.active ? Theme.fgBright : Theme.fgFaint
        opacity: root.available ? 1 : 0.5
    }

    HoverHandler {
        id: hover

        enabled: root.available
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.available
        onTapped: root.toggled()
    }
}
