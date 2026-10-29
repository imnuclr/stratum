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
    /*
     * A left-edge bar puts its popouts beside the trigger instead of beneath it.
     * Both cases are the same surface — only which axis is clamped and which is
     * fixed to the bar's edge changes.
     */
    property bool vertical: false
    property real barEdge: 0

    // The bar window masks input to this rect, so it must be empty when closed.
    readonly property alias maskItem: maskRect
    readonly property bool mine: Popouts.monitorName === monitorName
    readonly property bool shown: Popouts.open && mine

    anchors.fill: parent

    // Bridges the gap between the bar strip and the panel. The HoverHandler's
    // margin is worthless on its own: input outside the window's mask never
    // reaches the client, so the pointer would cross unmasked space on the way
    // down and the popout would close before reaching the panel.
    readonly property real bridge: Theme.space(1) + Theme.space(2)

    Item {
        id: maskRect

        // The mask reaches back over the gap to the bar, so the pointer can cross
        // from the trigger to the panel without leaving the surface.
        x: root.vertical ? frame.x - root.bridge : frame.x
        y: root.vertical ? frame.y : frame.y - root.bridge
        width: root.shown ? frame.width + (root.vertical ? root.bridge : 0) : 0
        height: root.shown ? frame.height + (root.vertical ? 0 : root.bridge) : 0
    }

    Tile {
        id: frame

        /*
         * Size the content wants, before the Behaviors smooth it. The clamp below
         * has to use this rather than `width`: computing it from the animating
         * width positions the panel for the size it is leaving, so switching to a
         * wider popout settled slightly off screen and then visibly corrected
         * itself once the width animation caught up. Driving x and width from the
         * same instant target makes the two animate in lockstep — the panel
         * morphs from one shape to the next.
         */
        readonly property real targetWidth: content.implicitWidth + Theme.space(3) * 2
        readonly property real targetHeight: content.implicitHeight + Theme.space(3) * 2

        // Clamped so a popout under an item near the edge stays on screen.
        x: root.vertical
            ? root.barEdge + Theme.space(1)
            : Math.max(Theme.space(1), Math.min(root.width - targetWidth - Theme.space(1),
                Popouts.anchorX - targetWidth / 2))
        y: root.vertical
            ? Math.max(Theme.space(1), Math.min(root.height - targetHeight - Theme.space(1),
                Popouts.anchorY - targetHeight / 2))
            : root.barBottom + Theme.space(1)

        width: targetWidth
        height: targetHeight

        level: 0
        floating: true
        radius: Theme.rTile

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.96
        // Grows out of the edge it hangs off, so the motion reads as the panel
        // emerging from the bar rather than appearing in place.
        transformOrigin: root.vertical ? Item.Left : Item.Top
        visible: opacity > 0.001
        // Content is laid out at full size while the frame is still animating to
        // it, so without this it spills above and below the panel for a frame or
        // two. Corners stay clean because the content is inset by its padding.
        clip: true

        /*
         * True only once the frame is already on screen. Position and size are
         * animated when moving between two triggers, but jumped to when the
         * popout first appears — otherwise the first open slides in from the
         * clamped default position at the left edge of the screen, and grows
         * from the placeholder content size.
         */
        readonly property bool settled: opacity > 0.5

        Behavior on x {
            enabled: frame.settled

            NumberAnimation {
                duration: Theme.expressiveMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        Behavior on width {
            enabled: frame.settled

            NumberAnimation {
                duration: Theme.expressiveMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        Behavior on height {
            enabled: frame.settled

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

        /*
         * A HoverHandler rather than a MouseArea: a parent MouseArea loses hover
         * to any child MouseArea that has hoverEnabled set, and fires its own
         * onExited when it does — so every switch, radio and button in the panel
         * read as the pointer leaving, and the popout closed under the cursor as
         * soon as you stopped moving or went to click something. A HoverHandler
         * stays hovered while the pointer is over a child.
         *
         * The margin also extends the region up into the gap between the bar and
         * the panel, so travelling down from the bar item never crosses
         * unhovered space.
         */
        HoverHandler {
            id: surfaceHover

            margin: Theme.space(1) + Theme.space(2)
        }

        /*
         * Only the monitor showing the popout drives the shared hover state.
         * There is one of these per screen, so without the guard the other
         * monitor's binding — permanently false, since nothing is hovered there —
         * fights this one and whichever evaluates last wins.
         */
        Binding {
            target: Popouts
            property: "surfaceHovered"
            value: surfaceHover.hovered
            when: root.mine
            restoreMode: Binding.RestoreNone
        }

        Item {
            id: content

            // Anchored to the top rather than centred, so a change in height
            // grows the panel downwards instead of moving the content.
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Theme.space(3)
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

                /*
                 * Hidden while the frame is resizing to fit what is coming. The
                 * frame already animates its size, but swapping the content in
                 * the same instant meant the old layout was visible inside a box
                 * travelling to the new size, which read as a jump rather than
                 * one panel becoming another. Fading out first lets the frame
                 * morph empty and the new content arrive into a settled box.
                 */
                property bool swapping: false

                opacity: root.shown && !swapping ? 1 : 0

                onSourceChanged: {
                    if (root.shown)
                        swapping = true;
                    settle.restart();
                }

                Timer {
                    id: settle

                    // Tracks the frame's own size animation, so the content
                    // arrives as the box stops moving.
                    interval: Theme.expressiveMs
                    onTriggered: loader.swapping = false
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.micro
                    }
                }
            }
        }
    }
}
