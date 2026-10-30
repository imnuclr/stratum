import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.theme
import qs.modules.bar.popouts

/*
 * Three floating islands on a transparent strip, plus the popout surface.
 *
 * The window is taller than the bar so popouts can hang below it in the same
 * coordinate space as the items that trigger them. Input is masked to the strip
 * and the open popout, so the empty region below the bar stays click-through,
 * and the exclusive zone still reserves only the bar itself.
 *
 * `layout: "edges"` puts the islands at the screen corners. `"thirds"` instead
 * places them at 25 / 50 / 75%, which keeps the clock and the status cluster
 * closer together on a very wide display.
 */
PanelWindow {
    id: root

    required property ShellScreen monitor

    readonly property string name: monitor.name
    readonly property int barHeight: Config.forMonitor(name, "bar.height", 38)
    readonly property int margin: Config.forMonitor(name, "bar.margin", 10)
    readonly property string layout: Config.forMonitor(name, "bar.layout", "edges")
    readonly property bool onTop: Config.forMonitor(name, "bar.edge", "top") === "top"
    readonly property int popoutSpace: Config.forMonitor(name, "bar.popoutSpace", 480)

    readonly property int stripHeight: barHeight + margin * 2

    screen: monitor
    visible: Config.forMonitor(name, "bar.enabled", true)
    color: "transparent"
    implicitHeight: stripHeight + popoutSpace
    WlrLayershell.layer: WlrLayer.Top
    // Popouts hold text fields for wifi passphrases, so the surface must be able
    // to take focus on click — but never to grab it, or the bar would steal
    // keyboard focus from the focused window just by existing.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: root.onTop
        bottom: !root.onTop
        left: true
        right: true
    }

    // Reserve only the bar's own height, not the margins or the popout space, so
    // windows sit flush under the floating islands.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barHeight + margin

    margins {
        top: root.onTop ? root.margin : 0
        bottom: root.onTop ? 0 : root.margin
    }

    // Everything outside the bar strip and the open popout is click-through.
    FadeBand {
        vertical: false
        atStart: root.onTop
        solid: root.barHeight + root.margin
        anchors.left: parent.left
        anchors.top: root.onTop ? parent.top : undefined
        anchors.bottom: root.onTop ? undefined : parent.bottom
    }

    mask: Region {
        item: strip

        regions: [
            Region {
                item: popout.maskItem
            }
        ]
    }

    Item {
        id: strip

        height: root.barHeight
        y: root.onTop ? 0 : parent.height - height
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.margin
        anchors.rightMargin: root.margin

        LeftIsland {
            id: left

            monitorName: root.name
            height: root.barHeight
            x: root.layout === "thirds" ? parent.width * 0.25 - width / 2 : 0
        }

        CentreIsland {
            id: centre

            monitorName: root.name
            height: root.barHeight
            x: parent.width * 0.5 - width / 2
        }

        RightIsland {
            id: right

            monitorName: root.name
            height: root.barHeight
            x: root.layout === "thirds" ? parent.width * 0.75 - width / 2 : parent.width - width
        }
    }

    BarPopout {
        id: popout

        monitorName: root.name
        barBottom: strip.y + strip.height
    }
}
