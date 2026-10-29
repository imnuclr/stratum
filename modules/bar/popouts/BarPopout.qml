import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * One popout surface per monitor, shared by every bar item.
 *
 * Reusing a single surface is what produces the fluid hand-off: moving from the
 * wifi glyph to the bluetooth glyph swaps the content and animates the frame to
 * its new size and position, rather than closing one window and opening another.
 */
PanelWindow {
    id: root

    required property ShellScreen monitor

    readonly property bool mine: Popouts.monitorName === monitor.name
    readonly property bool shown: Popouts.open && mine

    visible: shown || frame.opacity > 0.001

    screen: monitor
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Hover-driven, so it must never steal the keyboard.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Config.get("bar.height", 38) + Config.get("bar.margin", 10) + 260

    Tile {
        id: frame

        readonly property real target: Math.max(Theme.space(1),
            Math.min(root.width - width - Theme.space(1), Popouts.anchorX - width / 2))

        x: target
        y: Config.get("bar.height", 38) + Config.get("bar.margin", 10) + Theme.space(0)

        width: content.implicitWidth + Theme.space(3) * 2
        height: content.implicitHeight + Theme.space(3) * 2

        level: 0
        floating: true
        radius: Theme.rTile

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.95
        transformOrigin: Item.Top

        // Position, size and content all animate, so a hand-off between two bar
        // items reads as one object moving rather than two windows blinking.
        Behavior on x {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.standard
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.space(2)
            hoverEnabled: true
            // Travelling from the bar item into the popout must not close it.
            onEntered: Popouts.keepOpen()
            onExited: Popouts.requestHide()
        }

        Item {
            id: content

            anchors.centerIn: parent
            implicitWidth: loader.item?.implicitWidth ?? 180
            implicitHeight: loader.item?.implicitHeight ?? 80

            Loader {
                id: loader

                anchors.fill: parent
                // Keep the last content while fading out, or the frame empties
                // before it has finished shrinking.
                source: {
                    switch (Popouts.current) {
                    case "network":
                        return "NetworkPopout.qml";
                    case "bluetooth":
                        return "BluetoothPopout.qml";
                    case "audio":
                        return "AudioPopout.qml";
                    default:
                        return loader.source;
                    }
                }

                opacity: root.shown ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.micro
                    }
                }
            }
        }
    }
}
