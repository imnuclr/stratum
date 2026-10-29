import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.config
import qs.services

/*
 * Every panel in the shell is one of these. Sheet owns anchoring, the backdrop,
 * focus grab, Esc, click-outside and the origin-anchored grow transition, so a
 * module supplies content and nothing else.
 *
 * Panels never manage their own visibility: Shell.openPanel is the single source
 * of truth, and `name` is what it matches against.
 */
PanelWindow {
    id: root

    default property alias content: body.data

    required property string name
    required property ShellScreen monitor

    // Fraction across the screen the sheet grows from, so it appears to come out
    // of whichever bar island opened it.
    property real originX: 0.5
    property int sheetWidth: 400
    property int sheetHeight: 500

    readonly property bool open: Shell.openPanel === name

    screen: monitor
    visible: open || closing.running
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Click-outside dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: Shell.close()
    }

    Rectangle {
        id: body

        x: Math.round(Math.max(Theme.space(1),
            Math.min(root.width - width - Theme.space(1), root.width * root.originX - width / 2)))
        y: Theme.space(1) + Config.get("bar.height", 38) + Config.get("bar.margin", 10)

        width: root.sheetWidth
        height: root.sheetHeight
        radius: Theme.rSheet
        color: Theme.surface
        border.width: 1
        border.color: Theme.line

        transformOrigin: Item.Top
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96

        // Swallow clicks so they don't reach the dismiss layer underneath.
        MouseArea {
            anchors.fill: parent
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.sheetMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        Behavior on scale {
            NumberAnimation {
                id: closing

                duration: Theme.sheetMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }
    }

    Keys.onEscapePressed: Shell.close()
}
