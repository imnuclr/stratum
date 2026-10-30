import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.theme

/*
 * Whatever is sliding past the bar fades out before it reaches it.
 *
 * While the workspace changes, a band along the bar's edge — the colour of the
 * desktop, solid under and just around the bar and dissolving outward — lies over
 * the windows, so the bar and the space around it stay clear however the windows
 * move. It is only there during the change: left up all the time it would dim the
 * edge of every window that sits beside the bar.
 *
 * Under the bar's own surface (created first, so mapped below it) and
 * click-through.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        readonly property string name: modelData.name
        readonly property bool vertical: Config.forMonitor(name, "bar.orientation", "vertical") === "vertical"
        readonly property string edge: Config.forMonitor(name, "bar.edge", win.vertical ? "left" : "top")
        readonly property bool atStart: win.edge === "left" || win.edge === "top"
        readonly property int margin: Config.forMonitor(name, "bar.margin", 10)
        readonly property int barThickness: win.vertical
            ? Config.forMonitor(name, "bar.width", 56)
            : Config.forMonitor(name, "bar.height", 38)
        // Bar and its margins, solid; then the dissolve.
        readonly property real solid: win.barThickness + win.margin * 2
        readonly property real dissolve: 56
        readonly property real total: win.solid + win.dissolve

        // True for a moment after the workspace changes.
        property bool moving: false

        readonly property int workspace: Hyprland.monitorFor(win.modelData)?.activeWorkspace?.id ?? 0
        onWorkspaceChanged: {
            win.moving = true;
            hold.restart();
        }

        Timer {
            id: hold

            interval: 650
            onTriggered: win.moving = false
        }

        screen: modelData
        visible: Config.forMonitor(name, "bar.enabled", true)
        color: "transparent"
        mask: Region {}
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "stratum-barfade"

        anchors {
            left: win.vertical ? win.atStart : true
            right: win.vertical ? !win.atStart : true
            top: win.vertical ? true : win.atStart
            bottom: win.vertical ? true : !win.atStart
        }

        implicitWidth: win.vertical ? win.total : 0
        implicitHeight: win.vertical ? 0 : win.total

        Rectangle {
            anchors.fill: parent
            opacity: win.moving ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: win.moving ? Theme.micro : Theme.sheetMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            gradient: Gradient {
                orientation: win.vertical ? Gradient.Horizontal : Gradient.Vertical

                GradientStop {
                    position: 0
                    color: win.atStart ? Qt.alpha(Theme.bg, 0.97) : Qt.alpha(Theme.bg, 0)
                }
                GradientStop {
                    position: win.atStart ? win.solid / win.total : 1 - win.solid / win.total
                    color: Qt.alpha(Theme.bg, 0.97)
                }
                GradientStop {
                    position: 1
                    color: win.atStart ? Qt.alpha(Theme.bg, 0) : Qt.alpha(Theme.bg, 0.97)
                }
            }
        }
    }
}
