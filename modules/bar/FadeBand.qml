import QtQuick
import Quickshell.Hyprland
import qs.theme

/*
 * Whatever is sliding past the bar fades out before it reaches it.
 *
 * For a moment after the workspace changes, a band in the desktop colour lies
 * along the bar's edge, solid under the bar and dissolving outward, so the bar and
 * the space beside it stay clear however the windows move. It is only up during
 * the change: left up all the time it would dim the edge of every window that sits
 * beside the bar.
 *
 * Drawn inside the bar's own window, which is known to be on screen and above
 * the windows, rather than in a surface of its own. Place it first in the window
 * so the bar is drawn over it.
 */
Item {
    id: root

    property bool vertical: true
    // Whether the bar is at the left or top edge, as opposed to right or bottom.
    property bool atStart: true
    // How far the colour stays solid: the bar and the margin around it.
    property real solid: 66
    // How far it dissolves outward. Wider while the workspace is changing, so
    // what is sliding past is feathered well before it reaches the bar.
    property real dissolve: 88

    readonly property real total: root.solid + root.dissolve

    property bool moving: false

    width: root.vertical ? root.total : parent.width
    height: root.vertical ? parent.height : root.total

    // Hyprland's own announcement of a change, which does not wait on a property
    // to refresh.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2"
                    || event.name === "focusedmon" || event.name === "focusedmonv2") {
                root.moving = true;
                hold.restart();
            }
        }

        function onFocusedWorkspaceChanged() {
            root.moving = true;
            hold.restart();
        }

        function onActiveToplevelChanged() {
            // A window brought forward from another workspace slides in too.
            root.moving = true;
            hold.restart();
        }
    }

    Timer {
        id: hold

        interval: 900
        onTriggered: root.moving = false
    }

    Rectangle {
        anchors.fill: parent
        opacity: root.moving ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.moving ? Theme.micro : Theme.sheetMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.soft
            }
        }

        gradient: Gradient {
            orientation: root.vertical ? Gradient.Horizontal : Gradient.Vertical

            GradientStop {
                position: 0
                color: root.atStart ? Qt.alpha(Theme.bg, 0.97) : Qt.alpha(Theme.bg, 0)
            }
            GradientStop {
                position: root.atStart ? root.solid / root.total : 1 - root.solid / root.total
                color: Qt.alpha(Theme.bg, 0.97)
            }
            GradientStop {
                position: 1
                color: root.atStart ? Qt.alpha(Theme.bg, 0) : Qt.alpha(Theme.bg, 0.97)
            }
        }
    }
}
