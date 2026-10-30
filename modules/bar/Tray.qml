import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.components
import qs.config
import qs.services
import qs.theme
import qs.utils

/*
 * System tray, collapsed behind a chevron and expanding in place.
 *
 * The reveal runs in two phases, and the order reverses between them. Opening
 * widens the container first and then staggers the icons in; closing clears the
 * icons first and only then collapses the container.
 *
 * Overlapping the two is what made it snap at both ends. The container clips, so
 * while its width is still animating it is cutting a hard edge through whatever
 * is inside: on the way out the icons were uncovered by the clip faster than they
 * could fade in, and on the way back the width reached zero while the last icons
 * were still fading, which chopped them off mid-fade. Sequencing the phases means
 * the clip edge never crosses a visible icon.
 */
Row {
    id: root

    // Hover-driven, with a grace period so the row doesn't collapse while the
    // pointer is crossing into it.
    /*
     * Open while hovered, for a moment after, and while an icon is being pressed.
     * Pressing an icon takes the pointer, which clears the hover — so the tray
     * began closing under the click, the icon switched itself off before the
     * release, and nothing in the tray could be clicked at all.
     */
    property bool holding: false
    property string monitorName: ""
    // Kept open while one of its icons has its popout up, so the icon the panel
    // hangs from does not fold away under it.
    readonly property bool expanded: Config.get("bar.tray", "hover") === "show" || hover.hovered || closing.running || root.holding
        || (Popouts.open && Popouts.current.startsWith("tray:") && Popouts.monitorName === root.monitorName)

    HoverHandler {
        id: hover

        // Collapsed, the row is only as wide as the chevron, which is a small
        // target to ask someone to hit.
        margin: Theme.space(2)

        onHoveredChanged: {
            if (hovered)
                closing.stop();
            else
                closing.restart();
        }
    }

    Timer {
        id: closing

        interval: 220
    }

    readonly property var items: SystemTray.items?.values ?? []
    readonly property bool hasItems: items.length > 0

    // Per-icon reveal, and how long the whole staggered run takes.
    readonly property int itemMs: 170
    readonly property int itemStagger: 30
    readonly property int itemsSpan: Math.max(0, items.length - 1) * itemStagger + itemMs

    readonly property int widthMs: 240

    spacing: Theme.space(1)
    visible: hasItems

    Glyph {
        id: chevron

        anchors.verticalCenter: parent.verticalCenter
        name: "chevron-down"
        size: 15
        color: mouse.containsMouse || root.expanded ? Theme.fg : Theme.fgFaint
        rotation: root.expanded ? 90 : 0

        // Overshoot on the way out, settle on the way back. An overshooting curve
        // run in reverse undershoots and snaps at the end.
        Behavior on rotation {
            NumberAnimation {
                duration: root.expanded ? Theme.expressiveMs : Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: root.expanded ? Theme.expressive : Theme.exitEasing
            }
        }

        // Hover is handled for the row as a whole, above. A click toggle here
        // would fight it: collapsing while still hovered reopens immediately.
        MouseArea {
            id: mouse

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
    }

    Item {
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        height: 18
        // Leading padding so the first icon isn't clipped against the edge.
        width: root.expanded ? icons.implicitWidth + Theme.space(1) : 0

        // Opens immediately; on close, waits for the icons to clear first.
        Behavior on width {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.expanded ? 0 : root.itemsSpan
                }
                NumberAnimation {
                    duration: root.widthMs
                    easing.type: Easing.Bezier
                    // Eased both ends in both directions: the container changing
                    // size is the most visible part of this, and a decelerating
                    // curve front-loads it into something that looks like a snap.
                    easing.bezierCurve: Theme.smooth
                }
            }
        }

        Row {
            id: icons

            x: Theme.space(1)
            spacing: Theme.space(2)

            Repeater {
                model: root.items

                Item {
                    id: entry

                    required property var modelData
                    required property int index

                    /*
                     * Opening waits until the container is most of the way out,
                     * then runs left to right. Closing runs right to left and
                     * starts at once, so the row folds back toward the chevron
                     * before the container follows it.
                     */
                    readonly property int delay: root.expanded
                        ? Math.round(root.widthMs * 0.4) + index * root.itemStagger
                        : (root.items.length - 1 - index) * root.itemStagger

                    width: 17
                    height: 17
                    anchors.verticalCenter: parent.verticalCenter

                    opacity: root.expanded ? 1 : 0
                    scale: root.expanded ? 1 : 0.55

                    /*
                     * Slides out of the chevron rather than fading in place.
                     *
                     * Applied as a transform, not by assigning x: a Row owns its
                     * children's x, and writing to it from the delegate fights
                     * the positioner and stacks every icon at the same place —
                     * which it does silently, since only anchors inside a
                     * positioner produce a warning.
                     */
                    transform: Translate {
                        x: root.expanded ? 0 : -Theme.space(3)

                        Behavior on x {
                            SequentialAnimation {
                                PauseAnimation {
                                    duration: entry.delay
                                }
                                NumberAnimation {
                                    duration: root.itemMs
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: root.expanded ? Theme.expressive : Theme.exitEasing
                                }
                            }
                        }
                    }

                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: entry.delay
                            }
                            NumberAnimation {
                                duration: root.itemMs
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Behavior on scale {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: entry.delay
                            }
                            NumberAnimation {
                                duration: root.itemMs
                                easing.type: Easing.Bezier
                                easing.bezierCurve: root.expanded ? Theme.expressive : Theme.exitEasing
                            }
                        }
                    }

                    TrayIcon {
                        anchors.fill: parent
                        item: entry.modelData
                        edge: Edges.Bottom
                        monitorName: root.monitorName
                        onHeld: down => root.holding = down
                    }
                }
            }
        }
    }
}
