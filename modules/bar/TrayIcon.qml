import QtQuick
import Quickshell
import qs.components
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

    MouseArea {
        anchors.fill: parent
        anchors.margins: -3
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onPressed: root.held(true)
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
