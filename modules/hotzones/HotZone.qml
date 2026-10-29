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

    readonly property bool vertical: edge === "left" || edge === "right"

    screen: monitor
    visible: Config.forMonitor(monitor.name, "hotzones.enabled", true)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Below the panels it opens, so a panel covering the zone takes the pointer
    // rather than the zone re-triggering underneath it.
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    implicitWidth: vertical ? zoneDepth : zoneLength
    implicitHeight: vertical ? zoneLength : zoneDepth

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

        width: root.vertical ? root.zoneDepth : root.zoneLength
        height: root.vertical ? root.zoneLength : root.zoneDepth
        x: root.vertical ? 0 : Math.round((root.width - width) * root.along)
        y: root.vertical ? Math.round((root.height - height) * root.along) : 0

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    Shell.openOnHover(root.panel);
                    Shell.hold();
                } else {
                    Shell.release();
                }
            }
        }
    }
}
