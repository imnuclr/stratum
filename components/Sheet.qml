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

    default property alias content: card.data

    required property string name
    required property ShellScreen monitor

    // Fraction across the screen the sheet grows from, so it appears to come out
    // of whichever bar island opened it.
    property real originX: 0.5
    // 0 pins to the top edge, 1 to the bottom. A sheet reached from a corner has
    // to grow out of that corner, or the motion points the wrong way.
    property real originY: 0

    /*
     * How much vertical room a sheet has between the two edge gaps. A sheet that
     * sizes itself from its content has to clamp to this: taller than this and it
     * cannot be placed, which used to send it to the top of the screen.
     */
    readonly property real edgeGapTop: Config.get("bar.orientation", "vertical") === "vertical"
        ? Config.get("bar.margin", 10) + Theme.space(1)
        : Config.get("bar.height", 38) + Config.get("bar.margin", 10) + Theme.space(1)
    readonly property real edgeGapBottom: Config.get("bar.margin", 10) + Theme.space(1)
    readonly property real availableHeight: monitor.height - edgeGapTop - edgeGapBottom
    property int sheetWidth: 400
    property int sheetHeight: 500

    /*
     * Built per screen, so the panel being open is not enough — it has to be
     * open *here*. An empty openScreen means no pointer was involved (IPC, a
     * keybind) and every screen would be as good as another, so the monitor the
     * bar is on takes it.
     */
    readonly property bool open: Shell.openPanel === name
        && (Shell.openScreen.length === 0 ? monitor.name === Shell.fallbackScreen : Shell.openScreen === monitor.name)

    // Panels opened by hover keep themselves alive while hovered; Shell counts
    // the holds and closes once nothing is holding.
    property bool hoverDismiss: false

    // The window stays mapped until the exit transition has finished, otherwise
    // the sheet vanishes instead of shrinking.
    visible: open || card.opacity > 0.001

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

        /*
         * Fixed geometry: where the sheet sits when it is open, and nowhere else.
         * The input mask and the hover that holds the sheet open both read this
         * item, so neither moves while the sheet animates.
         *
         * That matters because the sheet is reached from a hot zone at the screen
         * edge. Animating this item's own position put its mask over that zone
         * for the length of the slide, the zone lost the pointer, and the panel
         * closed and reopened on a stationary cursor. The card inside does the
         * moving instead.
         */
        Item {
            id: body

            readonly property real barOffset: Config.get("bar.orientation", "vertical") === "vertical"
                ? Config.get("bar.width", 56) + Config.get("bar.margin", 10) + Theme.space(1)
                : 0

            // Clamped so a sheet growing from an item near the far edge stays on
            // screen rather than hanging off it.
            x: Math.round(Math.max(barOffset + Theme.space(1),
                Math.min(parent.width - width - Theme.space(1),
                    barOffset + (parent.width - barOffset) * root.originX - width / 2)))

            readonly property real edgeGap: root.edgeGapTop

            /*
             * A sheet anchored to the bottom pins its bottom edge, full stop. The
             * old form derived y from the space left over and floored that at
             * zero, so a sheet momentarily taller than the screen — which the
             * control centre is on a 1080 monitor while its content settles —
             * placed itself at the top and then travelled down as the height
             * resolved. That is the "opens from the top" everyone could see and I
             * could not reproduce: on a 1440 monitor it always fit.
             */
            y: root.originY >= 0.5
                ? Math.round(parent.height - root.edgeGapBottom - height)
                : Math.round(edgeGap + Math.max(0, root.availableHeight - height) * root.originY)

            width: root.sheetWidth
            height: root.sheetHeight

            /*
             * Whether the pointer is over the sheet at all, which is what keeps a
             * hover-opened sheet alive.
             *
             * This cannot be a plain HoverHandler on the body: the controls
             * inside — sliders, switches, buttons — are MouseAreas with
             * hoverEnabled, and a child MouseArea taking the hover event makes an
             * ancestor's handler report false. Tracing showed bodyHover flapping
             * true and false with no hot-zone events in between, which is the
             * pointer moving onto a toggle, not leaving the panel; resting on one
             * for longer than the grace closed the sheet under the pointer.
             *
             * So the handler lives on a transparent overlay above the content and
             * is non-blocking, which reports the hover without taking it away
             * from the controls underneath.
             */
            Item {
                anchors.fill: parent
                z: 999

                HoverHandler {
                    id: bodyHover

                    blocking: false

                    onHoveredChanged: {
                        Diag.log("sheet", `${root.name} bodyHover=${hovered} holds=${Shell.holds}`);
                        if (!root.hoverDismiss)
                            return;
                        if (hovered)
                            Shell.hold();
                        else
                            Shell.release();
                    }
                }
            }

            // Swallow clicks so they don't reach the dismiss layer underneath.
            MouseArea {
                anchors.fill: parent
            }

            Rectangle {
                id: card

                /*
                 * How far out of place the sheet sits while closed. One anchored
                 * to the bottom starts below where it belongs and rises into
                 * place; one anchored to the top starts above and comes down.
                 */
                property real slide: root.open ? 0 : (root.originY >= 0.5 ? 56 : -56)

                Behavior on slide {
                    NumberAnimation {
                        duration: root.open ? Theme.sheetMs : Math.round(Theme.sheetMs * 0.55)
                        easing.type: Easing.Bezier
                        easing.bezierCurve: root.open ? Theme.enterEasing : Theme.exitEasing
                    }
                }

                x: 0
                y: Math.round(slide)
                width: parent.width
                height: parent.height
                radius: Theme.rSheet
                color: Theme.surface
                border.width: 1
                border.color: Theme.lineHi

                transformOrigin: {
                    if (root.originY >= 0.5)
                        return root.originX >= 0.75 ? Item.BottomRight : (root.originX <= 0.25 ? Item.BottomLeft : Item.Bottom);
                    return root.originX >= 0.75 ? Item.TopRight : (root.originX <= 0.25 ? Item.TopLeft : Item.Top);
                }

                opacity: root.open ? 1 : 0
                scale: root.open ? 1 : 0.94

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
}
