import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme

/*
 * Three floating islands on a transparent strip.
 *
 * `layout: "thirds"` anchors them at 25 / 50 / 75% rather than left/centre/right.
 * On a 3440px display, edge anchoring puts 1,700px between the clock and the
 * status cluster; thirds keeps them readable as one bar.
 */
PanelWindow {
    id: root

    required property ShellScreen monitor

    readonly property string name: monitor.name
    readonly property int barHeight: Config.forMonitor(name, "bar.height", 38)
    readonly property int margin: Config.forMonitor(name, "bar.margin", 10)
    readonly property string layout: Config.forMonitor(name, "bar.layout", "thirds")
    readonly property bool onTop: Config.forMonitor(name, "bar.edge", "top") === "top"

    screen: monitor
    visible: Config.forMonitor(name, "bar.enabled", true)
    color: "transparent"
    implicitHeight: barHeight + margin * 2
    WlrLayershell.layer: WlrLayer.Top

    anchors {
        top: root.onTop
        bottom: !root.onTop
        left: true
        right: true
    }

    // Reserve only the bar's own height, not the margins, so windows sit flush
    // under the floating islands.
    margins {
        top: root.onTop ? root.margin : 0
        bottom: root.onTop ? 0 : root.margin
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: root.margin
        anchors.rightMargin: root.margin

        LeftIsland {
            id: left

            monitorName: root.name
            height: root.barHeight
            anchors.verticalCenter: parent.verticalCenter
            x: root.layout === "thirds" ? parent.width * 0.25 - width / 2 : 0
        }

        CentreIsland {
            id: centre

            monitorName: root.name
            height: root.barHeight
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * 0.5 - width / 2
        }

        RightIsland {
            id: right

            monitorName: root.name
            height: root.barHeight
            anchors.verticalCenter: parent.verticalCenter
            x: root.layout === "thirds" ? parent.width * 0.75 - width / 2 : parent.width - width
        }

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: Theme.standard
            }
        }
    }
}
