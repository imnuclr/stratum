import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.components
import qs.theme
import qs.utils

/*
 * System tray, collapsed behind a chevron and expanding in place.
 *
 * Items reveal on a stagger rather than all at once, and the order reverses on
 * close so the row folds back toward the chevron it came from. A single
 * simultaneous fade behind a width animation reads as a glitch, because the
 * icons appear at full opacity in a container that is still growing.
 */
Row {
    id: root

    property bool expanded: false

    readonly property var items: SystemTray.items?.values ?? []
    readonly property bool hasItems: items.length > 0
    readonly property int stagger: 34

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
        // Leading padding so the first icon isn't clipped mid-slide.
        width: root.expanded ? icons.implicitWidth + Theme.space(1) : 0

        Behavior on width {
            NumberAnimation {
                duration: root.expanded ? Theme.expressiveMs : Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: root.expanded ? Theme.enterEasing : Theme.exitEasing
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

                    // Forward on open, reverse on close, so the row folds back
                    // toward the chevron.
                    readonly property int delay: root.expanded
                        ? index * root.stagger
                        : (root.items.length - 1 - index) * Math.round(root.stagger * 0.6)

                    width: 17
                    height: 17
                    anchors.verticalCenter: parent.verticalCenter

                    opacity: root.expanded ? 1 : 0
                    scale: root.expanded ? 1 : 0.55
                    // Slides out of the chevron rather than fading in place.
                    x: root.expanded ? 0 : -Theme.space(3)

                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: entry.delay
                            }
                            NumberAnimation {
                                duration: Theme.standard
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
                                duration: root.expanded ? Theme.expressiveMs : Theme.standard
                                easing.type: Easing.Bezier
                                easing.bezierCurve: root.expanded ? Theme.expressive : Theme.exitEasing
                            }
                        }
                    }

                    Behavior on x {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: entry.delay
                            }
                            NumberAnimation {
                                duration: root.expanded ? Theme.expressiveMs : Theme.standard
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
