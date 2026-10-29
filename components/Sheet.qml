import QtQuick
import Quickshell
import Quickshell.Io
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

    /*
     * A second card above this one, for a list a control in the sheet opens.
     *
     * It sits outside the sheet rather than inside it because a sheet that grows
     * and shrinks to fit an expanding section moves its own edges under the
     * pointer: collapsing the section pulled the panel's boundary past the
     * pointer that had just clicked, hover ended, and the whole thing closed. A
     * separate card leaves the sheet exactly where it is.
     */
    property alias satellite: halo.data
    property real satelliteHeight: 0

    readonly property real satelliteGap: Theme.space(2)
    readonly property real satelliteRoom: root.satelliteHeight > 0
        ? root.satelliteHeight + root.satelliteGap
        : 0

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
    // How far the sheet reaches sideways past its card, toward the screen edge.
    readonly property real bridge: Theme.space(1)

    // Most of the way off its own edge, capped so a tall sheet does not take an
    // age to arrive.
    readonly property real travel: Math.min(root.sheetHeight, 260)
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

    /*
     * One hold per sheet, taken when the pointer arrives and given back only
     * when it has demonstrably gone. Counting these rather than calling
     * Shell.hold directly keeps the count balanced however the pointer behaves.
     */
    property bool holding: false

    // The sheet's own screen in the layout, for comparing against a cursor
    // position, which Hyprland reports across the whole desk.
    readonly property real monitorX: monitor.x
    readonly property real monitorY: monitor.y

    function take() {
        if (root.holding)
            return;
        root.holding = true;
        Shell.hold();
    }

    function give() {
        if (!root.holding)
            return;
        root.holding = false;
        Shell.release();
    }

    // The window stays mapped until the exit transition has finished, otherwise
    // the sheet vanishes instead of shrinking.
    /*
     * The window stays mapped whether the sheet is shown or not.
     *
     * A window that only exists while open has no laid-out content until it
     * opens, so its height settles over the first few frames of being on screen —
     * the control centre's rect went 428x398 then 428x704 on consecutive opens,
     * the first one before its content had measured itself. That moves the input
     * mask under a stationary pointer, the compositor has to re-decide what the
     * pointer is over, and the sheet jitters and closes. It only showed on the
     * monitor whose sheet was opened least, because every instance pays this once
     * and the one that keeps closing never gets past it.
     *
     * Mapped from the start, the layout settles once at launch and an open is a
     * single region change. The cost is a transparent surface per sheet with no
     * input region, which composites to nothing.
     */
    visible: true

    onOpenChanged: {
        if (open && root.hoverDismiss)
            Shell.armDismiss();
        if (!open) {
            verify.stop();
            root.give();
        }
    }

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

    /*
     * Input reaches the sheet across the gap between it and the screen edge it
     * came from, not just over the card itself.
     *
     * A HoverHandler margin cannot do this: the mask is what the compositor
     * delivers pointer events into, so a handler claiming hover past the mask
     * gets an enter it is immediately told to take back. Tracing showed exactly
     * that — hovered going true then false at one unchanging position, inside the
     * margin, with the pointer not moving at all.
     *
     * Bridging to the edge is also the behaviour people expect: running the
     * pointer to the edge of the screen should not drop the panel that is sitting
     * against it, and the band is where the hot zone lives, so travelling from
     * the zone into the sheet never crosses dead ground.
     */
    readonly property real barOffset: Config.get("bar.orientation", "vertical") === "vertical"
        ? Config.get("bar.width", 56) + Config.get("bar.margin", 10) + Theme.space(1)
        : 0

    // Clamped so a sheet growing from an item near the far edge stays on screen
    // rather than hanging off it.
    readonly property real cardX: Math.round(Math.max(root.barOffset + Theme.space(1),
        Math.min(monitor.width - root.sheetWidth - Theme.space(1),
            root.barOffset + (monitor.width - root.barOffset) * root.originX - root.sheetWidth / 2)))

    /*
     * A sheet anchored to the bottom pins its bottom edge, full stop. Deriving y
     * from the space left over and flooring it at zero placed a sheet momentarily
     * taller than the screen at the top, travelling down as its height resolved —
     * the "opens from the top" that only ever happened on the shorter monitor,
     * where the control centre does not fit while its content settles.
     */
    readonly property real cardY: root.originY >= 0.5
        ? Math.round(monitor.height - root.edgeGapBottom - root.sheetHeight)
        : Math.round(root.edgeGapTop + Math.max(0, root.availableHeight - root.sheetHeight) * root.originY)

    readonly property real reachX: Math.round(root.cardX - (root.originX < 0.5 ? root.bridge : 0))
    readonly property real reachY: Math.round(root.cardY
        - (root.originY < 0.5 ? root.edgeGapTop : 0) - root.satelliteRoom)
    readonly property real reachW: Math.round(root.sheetWidth + root.bridge)
    readonly property real reachH: Math.round(root.sheetHeight + root.satelliteRoom
        + (root.originY < 0.5 ? root.edgeGapTop : root.edgeGapBottom))

    mask: Region {
        x: root.open ? root.reachX : 0
        y: root.open ? root.reachY : 0
        width: root.open ? root.reachW : 0
        height: root.open ? root.reachH : 0
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
        /*
         * Everything the mask lets through, as an actual item, with the sheet
         * inside it.
         *
         * The mask decides what the compositor delivers to this surface, but an
         * event still has to land on an item before a handler sees it. The band
         * bridging the card to the screen edge had no item in it, so input
         * arrived and hit nothing — and that band is exactly where the hot zone
         * sits. The sheet's mask covers the zone the moment it opens, so the
         * zone loses the pointer, and nothing here picked it up: the trace
         * showed the zone going false on the same frame the panel opened, no
         * sheet hover at all, and the grace closing it under a stationary
         * cursor.
         *
         * The sheet is a child rather than this being laid over it. An item
         * above the content, even one holding nothing but a hover handler, sits
         * between every control and the pointer; as the parent it sees the
         * hover across the whole reachable area and leaves the controls beneath
         * it untouched.
         */
        Item {
            id: reach

            x: root.reachX
            y: root.reachY
            width: root.reachW
            height: root.reachH

            HoverHandler {
                id: bodyHover

                blocking: false

                onHoveredChanged: {
                    Diag.log("sheet", `${root.name} bodyHover=${hovered} holds=${Shell.holds}`);
                    if (!root.hoverDismiss)
                        return;
                    if (hovered) {
                        verify.stop();
                        Shell.engage();
                        root.take();
                    } else {
                        // Let go at once so leaving closes the sheet without a
                        // wait. The poll below only ever puts the hold back.
                        root.give();
                        verify.restart();
                    }
                }
            }

            /*
             * A sheet does not let go until the pointer has actually left it.
             *
             * Losing hover is not the same as the pointer leaving. Qt can clear
             * hover when a child takes a pointer grab, which is what a click on
             * any control in the panel does — and the report was exactly that:
             * click anything and the panel closes under you. Rather than guess at
             * which grab does it, the release is checked against where the cursor
             * really is, which is also proof against any other spurious loss.
             *
             * The cost is a poll, and only while hover is lost but the pointer is
             * still inside — a window that should not normally exist at all.
             */
            Timer {
                id: verify

                // Shorter than the grace, so a rescue lands before the close.
                interval: 40
                repeat: true
                onTriggered: cursor.running = true
            }

            Process {
                id: cursor

                command: ["hyprctl", "cursorpos"]

                stdout: StdioCollector {
                    onStreamFinished: {
                        const parts = text.trim().split(",");
                        if (parts.length !== 2)
                            return;
                        const x = parseInt(parts[0], 10);
                        const y = parseInt(parts[1], 10);
                        const inside = x >= root.monitorX + root.reachX
                            && x < root.monitorX + root.reachX + root.reachW
                            && y >= root.monitorY + root.reachY
                            && y < root.monitorY + root.reachY + root.reachH;
                        if (inside) {
                            /*
                             * Hover said the pointer left and it had not:
                             * something took a grab, which is what clicking a
                             * control does. Put the hold back and keep watching —
                             * stopping here was a trap, because hover may never
                             * come back on its own and then nothing was left to
                             * notice the pointer eventually leaving. The panel
                             * stayed open for good once you had clicked in it.
                             */
                            root.take();
                            return;
                        }
                        verify.stop();
                        root.give();
                    }
                }
            }

            /*
             * Where a satellite is drawn: directly above the card, growing out of
             * the edge nearest the control that opened it.
             */
            Item {
                id: halo

                x: Math.round(root.cardX - root.reachX)
                y: 0
                width: root.sheetWidth
                height: root.satelliteHeight
                visible: root.satelliteHeight > 0
            }

            Item {
                id: body

                // Where the card sits inside the reachable area: the whole of it,
                // except for the band bridging to the screen edge.
                x: Math.round(root.cardX - root.reachX)

                y: Math.round(root.cardY - root.reachY)

                width: root.sheetWidth
                height: root.sheetHeight

                // Swallow clicks so they don't reach the dismiss layer underneath.
                MouseArea {
                    anchors.fill: parent
                }

                Rectangle {
                    id: card

                    /*
                     * How far out of place the sheet sits while closed. One
                     * anchored to the bottom starts below where it belongs and
                     * rises into place; one anchored to the top starts above and
                     * comes down.
                     *
                     * Far enough to read as a direction. At 56px the travel was
                     * swamped by the fade and the panel looked like it simply
                     * materialised — which is why a sheet rising from the bottom
                     * edge kept being described as arriving from the top. A
                     * bottom sheet now starts below the screen edge and comes up
                     * from it, the way a drawer does.
                     */
                    property real slide: root.open
                        ? 0
                        : (root.originY >= 0.5 ? root.travel : -root.travel)

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
                    // A hint, not the motion: the slide says where it came from.
                    scale: root.open ? 1 : 0.98

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
}
