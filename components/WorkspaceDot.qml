import QtQuick
import qs.theme

/*
 * One workspace, as a dot.
 *
 * Caelestia's sizing: the dot is a fraction of a fixed box — a quarter when the
 * workspace is empty, a third when something is on it, two thirds when it is the
 * one you are looking at. Size carries the whole state, so the row still reads
 * with the dots blurred out of focus, and the box never changes, so nothing
 * reflows while a dot grows.
 *
 * The motion is the point, not a garnish. Both the dot you left and the one you
 * arrived at move at once, so switching reads as the row handing focus over
 * rather than as two unrelated resizes. That only lands if the curve is allowed
 * to overshoot and settle, which needs room: Theme.expressive already arcs past
 * its target, but at the shell's standard 220ms the overshoot goes by too fast
 * to register and the dot just looks like it snapped. Caelestia gives the same
 * gesture 500ms, and that is the whole difference in feel.
 *
 * Size and colour are deliberately not the same length. Colour settles early
 * while the dot is still growing, so the two read as one event with a shape to
 * it rather than as a cross-fade that happens to resize.
 */
Item {
    id: root

    property bool focused: false
    property bool occupied: false
    // Lives on a display other than this bar's.
    property bool elsewhere: false
    property bool hovered: false
    property bool pressed: false

    // The box. The dot inside it is what changes.
    property real size: 22

    // How long the dot takes to settle, before the user's motion speed is
    // applied. Caelestia's expressive spatial duration.
    property int animMs: 500

    // Honours the motion speed setting, and collapses to an instant change in
    // calm and game modes, where Theme.speed is zero.
    readonly property int spatialMs: Math.round(root.animMs * Theme.speed)
    readonly property int effectsMs: Math.round(root.animMs * 0.4 * Theme.speed)

    // One animated property rather than a width and a height racing each other,
    // so the dot can never be caught mid-morph as an ellipse.
    property real diameter: size * (focused ? 2 / 3 : occupied ? 1 / 3 : 1 / 4)

    implicitWidth: size
    implicitHeight: size

    Behavior on diameter {
        NumberAnimation {
            duration: root.spatialMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.expressive
        }
    }

    Rectangle {
        anchors.centerIn: parent

        width: root.diameter
        height: root.diameter
        radius: width / 2

        // Press is a separate concern from state, and wants the opposite
        // timing: the state curve is long so its overshoot can be seen, while a
        // press has to answer the finger immediately or it feels broken. Kept on
        // scale rather than folded into the diameter so the two never fight for
        // the same property.
        scale: root.pressed ? 0.82 : 1

        Behavior on scale {
            NumberAnimation {
                duration: root.effectsMs
                easing.type: Easing.OutCubic
            }
        }

        color: {
            if (root.focused)
                return Theme.dotOn;
            if (root.elsewhere)
                return Theme.fgDim;
            if (root.occupied)
                return Qt.alpha(Theme.fg, root.hovered ? 0.8 : 0.55);
            return root.hovered ? Qt.alpha(Theme.fg, 0.35) : Theme.dotOff;
        }

        Behavior on color {
            ColorAnimation {
                duration: root.effectsMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }
}
