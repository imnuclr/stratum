import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme
import qs.modules.bar
import qs.modules.bar.popouts

/*
 * A single column pinned to one screen edge, with the popout surface beside it.
 *
 * Same arrangement as the horizontal bar turned ninety degrees: the window is
 * wider than the bar so popouts can sit in the bar's own coordinate space, input
 * is masked to the column and the open popout so the rest stays click-through,
 * and the exclusive zone reserves only the column itself.
 */
PanelWindow {
    id: root

    required property ShellScreen monitor

    readonly property string name: monitor.name
    readonly property int barWidth: Config.forMonitor(name, "bar.width", 56)
    readonly property int margin: Config.forMonitor(name, "bar.margin", 10)
    readonly property bool onLeft: Config.forMonitor(name, "bar.edge", "left") === "left"
    readonly property int popoutSpace: Config.forMonitor(name, "bar.popoutSpace", 480)

    screen: monitor
    visible: Config.forMonitor(name, "bar.enabled", true)
    color: "transparent"
    implicitWidth: barWidth + margin * 2 + popoutSpace
    WlrLayershell.layer: WlrLayer.Top
    // Popouts hold text fields for wifi passphrases, so the surface must be able
    // to take focus on click — but never to grab it, or the bar would steal
    // keyboard focus from the focused window just by existing.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        left: root.onLeft
        right: !root.onLeft
        top: true
        bottom: true
    }

    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barWidth + margin

    margins {
        left: root.onLeft ? root.margin : 0
        right: root.onLeft ? 0 : root.margin
    }

    mask: Region {
        item: column

        regions: [
            Region {
                item: popout.maskItem
            }
        ]
    }

    Tile {
        id: column

        // Matches the popout surface: a panel growing out of the bar should be the
        // same material as the bar, and level 1 is a shade lighter.
        level: 0
        x: root.onLeft ? 0 : parent.width - width
        width: root.barWidth
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: root.margin
        anchors.bottomMargin: root.margin
        radius: root.barWidth / 2

        StatusDot {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.space(2)
        }

        VerticalWorkspaces {
            id: workspaces

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.space(2) + 42 + Theme.space(4)
            monitorName: root.name
        }

        // Centred on the column rather than stacked under the workspaces: the
        // clock is the thing read most often, so it sits where the eye lands.
        VerticalClock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        VerticalStatus {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space(3)
            monitorName: root.name
        }
    }

    BarPopout {
        id: popout

        monitorName: root.name
        vertical: true
        barBottom: 0
        barEdge: root.onLeft ? column.width : 0
    }
}
