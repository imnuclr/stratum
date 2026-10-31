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
    // Off while the toggles are being arranged, so a tap or hover does not act.
    property bool interactive: true

    signal toggled
    signal held

    implicitWidth: 64
    implicitHeight: circle.height + caption.implicitHeight + Theme.space(2)

    Rectangle {
        id: circle

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 54
        height: 54
        radius: width / 2
        color: root.active ? Theme.fg : (hover.hovered && root.available && root.interactive ? Theme.surfaceTop : Theme.surfaceHi)
        opacity: root.available ? 1 : 0.45

        /*
         * The circle answers the press, not just the result. Held down it gives
         * a little, lifts slightly under the pointer, and settles when released —
         * so a toggle that takes a moment to actually take effect still feels
         * like it registered the click.
         */
        scale: press.pressed ? 0.92 : (hover.hovered && root.available && root.interactive ? 1.04 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.gentle
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        Glyph {
            anchors.centerIn: parent
            name: root.icon
            size: 21
            stroke: 1.8
            color: root.active ? Theme.bg : Theme.fgBright

            // The glyph turns over as the fill inverts beneath it, rather than
            // swapping colour against a circle that is still changing.
            Behavior on color {
                ColorAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }
        }
    }

    SectionLabel {
        id: caption

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.label
        color: root.active ? Theme.fgBright : Theme.fgFaint
        opacity: root.available ? 1 : 0.5

        Behavior on color {
            ColorAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    HoverHandler {
        id: hover

        enabled: root.available && root.interactive
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: press

        // Holding is how arranging starts; releasing sooner is a tap.
        enabled: root.available && root.interactive
        onTapped: root.toggled()
        onLongPressed: root.held()
    }
}
