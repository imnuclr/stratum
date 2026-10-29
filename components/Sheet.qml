import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.theme

/*
 * Every panel in the shell is one of these. Sheet owns anchoring, the backdrop,
 * focus grab, Esc, click-outside and the origin-anchored grow transition, so a
 * module supplies content and nothing else.
 *
 * Panels never hold their own visibility: Shell.openPanel is the single source
 * of truth and `name` is what it matches against.
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

    // The window stays mapped until the exit transition has finished, otherwise
    // the sheet vanishes instead of shrinking.
    visible: open || body.opacity > 0.001

    screen: monitor
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

    // Click anywhere outside the sheet dismisses it.
    MouseArea {
        anchors.fill: parent
        onClicked: Shell.close()
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Shell.close()

        Rectangle {
            id: body

            // Clamped so a sheet growing from an island near the screen edge stays
            // on screen rather than hanging off it.
            // Offset from whichever edge the bar occupies, and clamped so a sheet
            // growing from an item near the far edge stays on screen rather than
            // hanging off it.
            readonly property real barOffset: Config.get("bar.orientation", "vertical") === "vertical"
                ? Config.get("bar.width", 56) + Config.get("bar.margin", 10) + Theme.space(1)
                : 0

            x: Math.round(Math.max(barOffset + Theme.space(1),
                Math.min(parent.width - width - Theme.space(1),
                    barOffset + (parent.width - barOffset) * root.originX - width / 2)))
            y: Config.get("bar.orientation", "vertical") === "vertical"
                ? Config.get("bar.margin", 10) + Theme.space(1)
                : Config.get("bar.height", 38) + Config.get("bar.margin", 10) + Theme.space(1)

            width: root.sheetWidth
            height: root.sheetHeight
            radius: Theme.rSheet
            color: Theme.surface
            border.width: 1
            border.color: Theme.lineHi

            /*
             * Dismiss affordance at the bottom edge. Clicking outside already
             * closes the sheet, but nothing on the sheet itself said so.
             */
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.space(2)
                width: 9
                height: 9
                radius: width / 2
                color: grip.containsMouse ? Theme.fg : Theme.fgFaint

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                    }
                }

                MouseArea {
                    id: grip

                    anchors.fill: parent
                    anchors.margins: -8
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Shell.close()
                }
            }

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
                    duration: Theme.sheetMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.enterEasing
                }
            }
        }
    }
}
