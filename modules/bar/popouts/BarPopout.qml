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
    // A bar on the right edge opens its popouts to its left.
    property bool opensLeft: false

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
        x: root.vertical ? (root.opensLeft ? frame.x : frame.x - root.bridge) : frame.x
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
            ? (root.opensLeft ? root.barEdge - targetWidth - Theme.space(1) : root.barEdge + Theme.space(1))
            : Math.max(Theme.space(1), Math.min(root.width - targetWidth - Theme.space(1),
                Popouts.anchorX - targetWidth / 2))
        /*
         * Where the top edge sits. Latched when the popout opens or moves to a
         * different trigger, and deliberately not recomputed when the content
         * changes size. Centring on the trigger means half of any height change
         * becomes a slide, so switching between popouts of different heights
         * moved the panel as well as resizing it — which is most of what read as
         * a jump. Growing downward from a fixed top is one panel becoming
         * another.
         */
        property real latchedTop: 0

        function relatch() {
            frame.latchedTop = Popouts.anchorY - frame.targetHeight / 2;
            following.restart();
        }

        /*
         * Content that settles its size after the trigger changes is centred
         * again once it has. A tray menu arrives over D-Bus a moment after the
         * hover, so the panel was centred using the previous item's height: a
         * short Spotify menu opened far above its icon because Warp's tall one
         * had been measured instead. Only for a moment after a move, so content
         * growing later (a list expanding) still grows downward in place.
         */
        Timer {
            id: following

            interval: 450
        }

        onTargetHeightChanged: {
            if (following.running)
                frame.latchedTop = Popouts.anchorY - frame.targetHeight / 2;
        }

        onVisibleChanged: if (visible) frame.relatch()

        Connections {
            target: Popouts

            // A different trigger is a new position; the same trigger showing
            // different content is not.
            function onAnchorYChanged() {
                frame.relatch();
            }
        }

        // Still clamped, so taller content grows upward rather than off the
        // bottom of the screen.
        y: root.vertical
            ? Math.max(Theme.space(1), Math.min(root.height - targetHeight - Theme.space(1),
                frame.latchedTop))
            : root.barBottom + Theme.space(1)

        width: targetWidth
        height: targetHeight

        level: 0
        floating: true
        radius: Theme.rTile

        opacity: 1
        scale: 1
        // Grows out of the edge it hangs off, so the motion reads as the panel
        // emerging from the bar rather than appearing in place.
        transformOrigin: root.vertical ? (root.opensLeft ? Item.Right : Item.Left) : Item.Top
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

        /*
         * y had no Behavior at all, so moving from one trigger to the next jumped
         * the panel vertically while its size animated — a panel that is
         * simultaneously teleporting and morphing. All four now move together.
         */
        Behavior on y {
            enabled: frame.settled

            NumberAnimation {
                duration: Theme.popoutMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.soft
            }
        }

        Behavior on x {
            enabled: frame.settled

            NumberAnimation {
                duration: Theme.popoutMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.soft
            }
        }

        Behavior on width {
            enabled: frame.settled

            NumberAnimation {
                duration: Theme.popoutMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.soft
            }
        }

        Behavior on height {
            enabled: frame.settled

            NumberAnimation {
                duration: Theme.popoutMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.soft
            }
        }

        /*
         * Appearing and leaving are different lengths, so they are different
         * transitions rather than one Behavior with a conditional duration.
         *
         * `duration: shown ? a : b` on a Behavior depends on the same value the
         * Behavior is reacting to, and Qt does not say which updates first. It did
         * not work: leaving ran the full entrance length, measured at 403ms
         * against a 260 target. A transition between named states is chosen by
         * the direction of the change itself, so there is nothing to race.
         *
         * The fade was also linear before, while everything it travelled with was
         * eased: two curves on one panel, one of which had no shape.
         */
        states: State {
            name: "hidden"
            when: !root.shown

            PropertyChanges {
                frame.opacity: 0
                frame.scale: 0.97
            }
        }

        transitions: [
            Transition {
                from: "hidden"
                to: ""

                NumberAnimation {
                    properties: "opacity,scale"
                    duration: Theme.popoutMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            },
            Transition {
                from: ""
                to: "hidden"

                NumberAnimation {
                    properties: "opacity,scale"
                    duration: Theme.popoutExitMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }
        ]

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

            /*
             * One loader, swapped in three steps rather than one.
             *
             * Changing the source the instant the popout changes puts the new
             * content on screen at the old content's size, and the frame then
             * resizes around it — which is the jump. So: fade out quickly, adopt
             * the new content while nothing is visible, and fade back in slowly
             * enough that the frame has arrived at its new size by the time there
             * is anything to look at. The resize happens, as it must, but never
             * under something the eye is tracking.
             *
             * Two fancier versions were tried and both failed. Two loaders
             * crossfading needed a flag to say which was live, and the flag and
             * the source assignment did not commute — the old content stayed on
             * screen with Popouts.current already changed. Capturing the outgoing
             * layout into a ShaderEffectSource and fading that out left the frame
             * rendering empty.
             */
            Loader {
                id: loader

                // What the bar is asking for, and what is actually loaded.
                readonly property string want: Popouts.content
                property string have: Popouts.content

                onWantChanged: adopt.restart()

                // The panel is centred on its trigger using its own height, and
                // that height is the new content's only once it has loaded. It
                // was latched at hover time, against whatever was loaded before,
                // so a popout could open noticeably off its icon.
                onLoaded: frame.relatch()

                source: {
                    switch (loader.have) {
                    case "network":
                        return "NetworkPopout.qml";
                    case "bluetooth":
                        return "BluetoothPopout.qml";
                    case "audio":
                        return "AudioPopout.qml";
                    case "battery":
                        return "BatteryPopout.qml";
                    default:
                        // One per tray item, so moving between icons is a
                        // change of trigger; all of them share one panel.
                        return loader.have.startsWith("tray:") ? "TrayPopout.qml" : "";
                    }
                }

                opacity: 1

                /*
                 * Out fast, in over the length of the frame's resize. As states
                 * for the same reason as the frame: the duration used to depend on
                 * `have === want`, which changes at the instant the fade it
                 * controls begins.
                 */
                states: State {
                    name: "swapping"
                    when: !root.shown || loader.have !== loader.want

                    PropertyChanges {
                        loader.opacity: 0
                    }
                }

                transitions: [
                    Transition {
                        from: ""
                        to: "swapping"

                        NumberAnimation {
                            property: "opacity"
                            duration: Theme.micro
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.soft
                        }
                    },
                    Transition {
                        from: "swapping"
                        to: ""

                        NumberAnimation {
                            property: "opacity"
                            duration: Theme.popoutMs
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.soft
                        }
                    }
                ]

                Timer {
                    id: adopt

                    interval: Theme.micro
                    onTriggered: loader.have = loader.want
                }
            }
        }
    }
}
