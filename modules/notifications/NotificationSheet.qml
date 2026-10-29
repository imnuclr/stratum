import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme
/*
 * Notifications, on their own page at the top right.
 *
 * They used to be the tail of the control centre, which was the wrong home for
 * them twice over: the control centre is a place you go to change something and
 * leave, while a notification is read and dismissed, and an unbounded list at
 * the bottom of a fixed panel meant it was always the part that got cut. Here
 * the whole list is reachable and the control centre keeps its shape.
 *
 * Top right because that is where the toasts will appear — the page is the same
 * corner's history, so dismissing a toast and going to look for it later lead to
 * the same place.
 */
Sheet {
    id: root
    readonly property int listHeight: Config.get("notifications.listHeight", 460)
    name: "notifications"
    hoverDismiss: true
    originX: 1
    originY: 0
    sheetWidth: Config.get("notifications.width", 380)
    sheetHeight: Math.min(availableHeight, body.implicitHeight + Theme.space(4) * 2)
    // Ages are relative ("now", "4m"), so they only tick while someone is reading.
    onOpenChanged: open ? Notifs.watch() : Notifs.unwatch()
    Column {
        id: body
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.space(4)
        spacing: Theme.space(3)
        Item {
            width: parent.width
            height: header.implicitHeight + Theme.space(1)
            SectionLabel {
                id: header
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                text: Notifs.any ? `notifications · ${Notifs.count}` : "notifications"
            }
            SectionLabel {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                text: "clear all"
                color: clearHover.hovered ? Theme.fg : Theme.fgBright
                visible: Notifs.any
                HoverHandler {
                    id: clearHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: Notifs.clearAll()
                }
            }
        }
        /*
         * The list scrolls rather than the page growing without end. The sheet
         * sizes to its content up to this, so a couple of notifications make a
         * short panel instead of a tall one padded with nothing.
         */
        Flickable {
            width: parent.width
            height: Math.min(root.listHeight, list.implicitHeight)
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: Notifs.any
            Column {
                id: list
                width: parent.width
                spacing: Theme.space(2)
                Repeater {
                    model: Notifs.list
                    NotificationRow {
                        required property var modelData
                        width: list.width
                        notification: modelData
                    }
                }
            }
        }
        SectionLabel {
            dim: true
            text: "nothing to show"
            visible: !Notifs.any
        }
    }
}
