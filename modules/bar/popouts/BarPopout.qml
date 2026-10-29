import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The popout surface, hosted inside the bar window rather than in a window of
 * its own.
 *
 * It lived in a separate layer surface at first, and the anchor was consistently
 * wrong: a surface with ExclusionMode.Ignore spans the whole output, while the
 * bar respects other shells' exclusive zones and so starts 60px in on this
 * machine. The two had different origins, and nothing in the API reports a
 * layer surface's position, so the offset could not be recovered. Sharing the
 * bar's window makes the trigger's coordinates and the popout's the same
 * coordinates by construction.
 *
 * One surface serves every bar item, so moving between two triggers animates the
 * frame across instead of closing one popout and opening another.
 */
Item {
    id: root

    required property string monitorName
    required property real barBottom

    // The bar window masks input to this rect, so it must be empty when closed.
    readonly property alias maskItem: maskRect
    readonly property bool shown: Popouts.open && Popouts.monitorName === monitorName

    anchors.fill: parent

    Item {
        id: maskRect

        x: frame.x
        y: frame.y
        width: root.shown ? frame.width : 0
        height: root.shown ? frame.height : 0
    }

    Tile {
        id: frame

        // Clamped so a popout under an item near the edge stays on screen.
        x: Math.max(Theme.space(1), Math.min(root.width - width - Theme.space(1),
            Popouts.anchorX - width / 2))
        y: root.barBottom + Theme.space(1)

        width: content.implicitWidth + Theme.space(3) * 2
        height: content.implicitHeight + Theme.space(3) * 2

        level: 0
        floating: true
        radius: Theme.rTile

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        transformOrigin: Item.Top
        visible: opacity > 0.001

        Behavior on x {
            NumberAnimation {
                duration: Theme.expressiveMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.expressiveMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.expressiveMs
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
                duration: Theme.expressiveMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.expressive
            }
        }

        // Extends up into the gap between the bar and the frame, so travelling
        // from the bar item into the popout never crosses dead space.
        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -(Theme.space(1) + Theme.space(2))
            hoverEnabled: true
            onEntered: Popouts.keepOpen()
            onExited: Popouts.requestHide()
        }

        Item {
            id: content

            anchors.centerIn: parent
            implicitWidth: loader.item?.implicitWidth ?? 200
            implicitHeight: loader.item?.implicitHeight ?? 90

            Loader {
                id: loader

                anchors.fill: parent
                source: {
                    switch (Popouts.content) {
                    case "network":
                        return "NetworkPopout.qml";
                    case "bluetooth":
                        return "BluetoothPopout.qml";
                    case "audio":
                        return "AudioPopout.qml";
                    default:
                        return "";
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
