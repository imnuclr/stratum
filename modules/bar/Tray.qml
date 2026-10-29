import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.components
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

    property bool expanded: false

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

        MouseArea {
            id: mouse

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
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

                    Image {
                        id: icon

                        anchors.fill: parent
                        source: Icons.trayIcon(entry.modelData.icon)
                        // Matching the drawn size keeps small pixmaps from being
                        // upscaled into mush; mipmap covers the oversized ones.
                        sourceSize.width: Math.round(width * 2)
                        sourceSize.height: Math.round(height * 2)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                        asynchronous: true
                        visible: status === Image.Ready
                    }

                    // An icon that fails to resolve would otherwise leave an empty
                    // slot in the row that reads as a gap in the pill.
                    Glyph {
                        anchors.centerIn: parent
                        name: "app"
                        size: 13
                        color: Theme.fgFaint
                        visible: icon.status !== Image.Ready
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -2
                        enabled: root.expanded
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: event => {
                            const item = entry.modelData;
                            if (event.button === Qt.MiddleButton) {
                                item.secondaryActivate();
                            } else if (event.button === Qt.RightButton || item.onlyMenu) {
                                if (item.hasMenu)
                                    menu.open();
                            } else {
                                item.activate();
                            }
                        }
                    }

                    QsMenuAnchor {
                        id: menu

                        menu: entry.modelData.menu
                        anchor.item: entry
                        anchor.edges: Edges.Bottom
                    }
                }
            }
        }
    }
}
