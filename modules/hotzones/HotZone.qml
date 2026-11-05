import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.theme

/*
 * A strip at a screen edge that opens a panel when the pointer reaches it.
 *
 * Kept as thin as it can be and still be hit: the surface has to accept pointer
 * input to see the hover at all, so every pixel it covers is a pixel the window
 * underneath does not get. A few at the very edge is the trade; a comfortable
 * margin would mean swallowing clicks on whatever sits there.
 */
PanelWindow {
    id: root

    required property ShellScreen monitor
    required property string panel

    property string edge: "top"
    property real along: 0.5
    property int zoneLength: 320
    property int zoneDepth: 3
    property int dwell: 120
    /*
     * How far in from its edge the strip starts. A column bar sits on an edge
     * and is drawn above this, so a zone on the same edge would be a strip
     * nothing can reach: offset past it and the zone is the first thing beyond
     * the bar instead.
     */
    property int inset: 0

    /*
     * The zone grows once its panel is up, to cover the gap between the screen
     * edge and the panel itself. That strip belongs to neither — the zone is too
     * shallow to reach it and the panel's mask starts past it — so a pointer that
     * paused there on the way to the panel was hovering nothing, and the panel
     * closed out from under it. The zone sits below the panel, so growing it
     * cannot take input away from the panel's own controls.
     */
    readonly property bool mine: Shell.openPanel === panel
    readonly property int liveDepth: mine
        ? Math.max(zoneDepth, Config.get("bar.margin", 10) + Theme.space(2))
        : zoneDepth

    readonly property bool vertical: edge === "left" || edge === "right"

    screen: monitor
    visible: Config.forMonitor(monitor.name, "hotzones.enabled", true)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Below the panels it opens, so a panel covering the zone takes the pointer
    // rather than the zone re-triggering underneath it.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: vertical ? liveDepth + root.inset : zoneLength
    implicitHeight: vertical ? zoneLength : liveDepth + root.inset

    anchors {
        top: root.edge === "top" || root.vertical
        bottom: root.edge === "bottom" || root.vertical
        left: root.edge === "left" || !root.vertical
        right: root.edge === "right" || !root.vertical
    }

    mask: Region {
        item: zone
    }

    Item {
        id: zone

        width: root.vertical ? root.liveDepth : root.zoneLength
        height: root.vertical ? root.zoneLength : root.liveDepth
        // The inset is taken off whichever end the zone's own edge is, so the
        // strip itself keeps its depth and simply starts further in.
        x: root.vertical
            ? (root.edge === "right" ? 0 : root.inset)
            : Math.round((root.width - width) * root.along)
        y: root.vertical
            ? Math.round((root.height - height) * root.along)
            : (root.edge === "bottom" ? 0 : root.inset)

        HoverHandler {
            onHoveredChanged: {
                Diag.log("hotzone", `${root.panel} hover=${hovered} holds=${Shell.holds} open=${Shell.openPanel}`);
                if (hovered) {
                    Shell.hold();
                    dwell.restart();
                } else {
                    dwell.stop();
                    Shell.release();
                }
            }
        }

        /*
         * The pointer has to mean it. Crossing between monitors drags the
         * pointer straight through the corner zone of the one being left, which
         * was opening the control centre on every switch. A short dwell ignores
         * a pass-through without making a deliberate move feel sluggish.
         */
        Timer {
            id: dwell

            interval: root.dwell
            onTriggered: {
                Diag.log("hotzone", `${root.panel} dwell elapsed, opening on ${root.monitor.name}`);
                Shell.openOnHover(root.panel, root.monitor.name);
            }
        }
    }
}
