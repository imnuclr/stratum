import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.theme
import qs.utils

/*
 * One tray item: its icon, and what clicking it does — left activates it (or
 * opens its menu, if a menu is all it has), middle is its secondary action, right
 * opens its menu. The menu opens toward `edge`, away from the screen's edge.
 */
Item {
    id: root

    required property var item
    property int edge: Edges.Bottom
    property real size: 17
    // Where hovering shows the item's popout; empty for no popout.
    property string monitorName: ""
    property bool vertical: false
    readonly property string popoutName: `tray:${root.item?.id ?? ""}`

    signal held(bool down)

    width: root.size
    height: root.size

    Image {
        id: icon

        anchors.fill: parent
        source: Icons.trayIcon(root.item.icon)
        sourceSize.width: Math.round(width * 2)
        sourceSize.height: Math.round(height * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: true
        visible: status === Image.Ready
    }

    // An icon that fails to resolve would otherwise leave an empty slot.
    Glyph {
        anchors.centerIn: parent
        name: "app"
        size: root.size * 0.75
        color: Theme.fgFaint
        visible: icon.status !== Image.Ready
    }

    /*
     * Hovering shows what the item is and its menu as a popout, the same as
     * every other icon in the bar; clicking still does what the app asks.
     */
    HoverHandler {
        enabled: root.monitorName.length > 0

        onHoveredChanged: {
            if (hovered) {
                Popouts.trayItem = root.item;
                const centre = root.mapToItem(null, root.width / 2, root.height / 2);
                if (root.vertical)
                    Popouts.showAtY(root.popoutName, centre.y, root.monitorName);
                else
                    Popouts.show(root.popoutName, centre.x, root.monitorName);
            } else {
                Popouts.release(root.popoutName);
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -3
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onPressed: {
            root.held(true);
            if (root.monitorName.length > 0)
                Popouts.hide();
        }
        onReleased: root.held(false)
        onCanceled: root.held(false)

        onClicked: event => {
            const item = root.item;
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

        menu: root.item.menu
        anchor.item: root
        anchor.edges: root.edge
    }
}
