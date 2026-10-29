import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.components
import qs.theme

/*
 * System tray, collapsed behind a chevron and expanding in place.
 *
 * Caelestia pushes overflow into a popup menu; this just grows the island, which
 * keeps the bar a single surface and avoids a second window to manage.
 */
Row {
    id: root

    property bool expanded: false

    readonly property var items: SystemTray.items?.values ?? []
    readonly property bool hasItems: items.length > 0

    spacing: Theme.space(1)
    visible: hasItems

    Glyph {
        anchors.verticalCenter: parent.verticalCenter
        name: root.expanded ? "chevron-left" : "chevron-down"
        size: 15
        color: mouse.containsMouse ? Theme.fg : Theme.fgFaint

        MouseArea {
            id: mouse

            anchors.fill: parent
            anchors.margins: -3
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // Clipped so icons slide out of the chevron rather than popping in.
    Item {
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        height: 18
        width: root.expanded ? icons.implicitWidth : 0

        Behavior on width {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.enterEasing
            }
        }

        Row {
            id: icons

            spacing: Theme.space(2)

            Repeater {
                model: root.items

                Item {
                    id: entry

                    required property var modelData

                    width: 17
                    height: 17
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: root.expanded ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.standard
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: entry.modelData.icon
                        sourceSize.width: 34
                        sourceSize.height: 34
                        smooth: true
                        asynchronous: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -2
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
