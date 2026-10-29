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
    // 0 pins to the top edge, 1 to the bottom. A sheet reached from a corner has
    // to grow out of that corner, or the motion points the wrong way.
    property real originY: 0
    property int sheetWidth: 400
    property int sheetHeight: 500

    readonly property bool open: Shell.openPanel === name

    // Panels opened by hover keep themselves alive while hovered; Shell counts
    // the holds and closes once nothing is holding.
    property bool hoverDismiss: false

    // The window stays mapped until the exit transition has finished, otherwise
    // the sheet vanishes instead of shrinking.
    visible: open || body.opacity > 0.001

    screen: monitor
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    /*
     * Never Exclusive. A sheet that grabs the keyboard takes it from the focused
     * window for as long as it is up, which for a panel opened by hover means
     * typing stops working by accident. OnDemand still lets a text field inside
     * take focus once it is clicked.
     */
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        item: body
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
            readonly property real edgeGap: Config.get("bar.orientation", "vertical") === "vertical"
                ? Config.get("bar.margin", 10) + Theme.space(1)
                : Config.get("bar.height", 38) + Config.get("bar.margin", 10) + Theme.space(1)

            y: Math.round(edgeGap + Math.max(0, parent.height - height - edgeGap
                - Config.get("bar.margin", 10) - Theme.space(1)) * root.originY)

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

            HoverHandler {
                id: bodyHover

                onHoveredChanged: {
                    if (!root.hoverDismiss)
                        return;
                    if (hovered)
                        Shell.hold();
                    else
                        Shell.release();
                }
            }

            transformOrigin: {
                if (root.originY >= 0.5)
                    return root.originX >= 0.75 ? Item.BottomRight : (root.originX <= 0.25 ? Item.BottomLeft : Item.Bottom);
                return root.originX >= 0.75 ? Item.TopRight : (root.originX <= 0.25 ? Item.TopLeft : Item.Top);
            }
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96

            // Swallow clicks so they don't reach the dismiss layer underneath.
            MouseArea {
                anchors.fill: parent
            }

            /*
             * Leaving is quicker than arriving. A panel you have decided to
             * dismiss should get out of the way, while one arriving has to be
             * followed by the eye — the same duration both ways makes the exit
             * feel like it is lingering.
             */
            Behavior on opacity {
                NumberAnimation {
                    duration: root.open ? Theme.sheetMs : Math.round(Theme.sheetMs * 0.55)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.open ? Theme.enterEasing : Theme.exitEasing
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: root.open ? Theme.sheetMs : Math.round(Theme.sheetMs * 0.55)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: root.open ? Theme.enterEasing : Theme.exitEasing
                }
            }
        }
    }
}
