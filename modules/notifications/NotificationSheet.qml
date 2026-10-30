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

    // Ages are relative ("now", "4 min"), so they only tick while someone reads.
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
                color: Theme.fgBright
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
         *
         * A view rather than a column of repeated rows, because a column cannot
         * animate a removal: the row is destroyed the instant the model drops it
         * and everything below snaps up into the hole. A view holds a removed row
         * long enough to see it leave.
         */
        ListView {
            id: list

            width: parent.width
            height: Math.min(root.listHeight, contentHeight)
            model: Notifs.model
            spacing: Theme.space(2)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            /*
             * Visible while it still has height, not while the model still has
             * rows. Tying this to the model hid the view the instant the last
             * notification went, taking the row that was still animating out with
             * it — the removal ran correctly and nothing of it was ever drawn.
             */
            visible: height > 1

            /*
             * The view's height follows its content, and without this it snapped
             * to the new height the instant the model shrank — so with clipping
             * on, the row still animating out was cut away before a frame of it
             * could be seen. The removal was running correctly and was simply
             * invisible. Shrinking over the same span keeps the leaving row in
             * view for as long as it takes to leave.
             */
            Behavior on height {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

            delegate: NotificationRow {
                required property var modelData

                width: list.width
                notification: modelData
            }

            // An arrival comes in from the edge it arrived at the screen from.
            add: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.standard
                }

                NumberAnimation {
                    property: "x"
                    from: list.width / 3
                    to: 0
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

            /*
             * Dismissal fades in place rather than sliding out. The panel is
             * sized to its content, so it starts closing the gap at the same
             * moment — and a row travelling sideways out of a shrinking panel
             * escapes the card and is drawn outside it, which looks like a fault
             * rather than an animation. Fading where it stands reads cleanly
             * against the reflow, and it answers something the person just did,
             * so it is quick.
             */
            remove: Transition {
                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: Theme.micro
                }
            }

            // Whatever has to move to close the gap travels rather than jumps.
            displaced: Transition {
                NumberAnimation {
                    properties: "x,y"
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }
        }

        SectionLabel {
            dim: true
            text: "nothing to show"
            // Only once the list has finished collapsing, so the two do not
            // briefly occupy the panel together.
            visible: !Notifs.any && list.height <= 1
        }
    }
}
