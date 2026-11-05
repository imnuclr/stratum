import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The notification list: a header that counts them, and the groups beneath.
 *
 * Its own component because it is no longer a panel. Notifications used to live
 * on a page of their own, which meant the control centre carried a card whose
 * whole job was to say how many there were and send you somewhere else — two
 * panels, two hot corners, and a count you had to travel to act on. The list
 * now sits inside the control centre, and this is the part that moved.
 *
 * It fills whatever height it is given rather than sizing to its contents: it is
 * the part of the panel that takes the room left over, so the controls above it
 * keep their size and the list absorbs the difference.
 */
Item {
    id: root

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: title.implicitHeight + Theme.space(2)

        SectionLabel {
            id: title

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.fgBright
            text: "notifications"
        }

        /*
         * The count carries the accent only when something in the list is
         * Critical. A number that is always coloured says nothing; one that
         * colours when a sender marked something urgent is the whole reason the
         * shell bothers to read urgency at all.
         */
        Rectangle {
            id: badge

            anchors.left: title.right
            anchors.leftMargin: Theme.space(2)
            anchors.verticalCenter: title.verticalCenter

            visible: Notifs.any
            width: Math.max(height, countLabel.implicitWidth + Theme.space(2))
            height: countLabel.implicitHeight + 2
            radius: height / 2

            color: Notifs.anyCritical ? Theme.accent : Qt.alpha(Theme.fg, 0.12)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

            SectionLabel {
                id: countLabel

                anchors.centerIn: parent
                text: Notifs.count
                color: Notifs.anyCritical ? Theme.bg : Theme.fgBright
            }
        }

        SectionLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "clear all"
            color: clearHover.hovered ? Theme.accent : Theme.fgBright
            visible: Notifs.any

            Behavior on color {
                ColorAnimation {
                    duration: Theme.micro
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

            HoverHandler {
                id: clearHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: Notifs.clearAll()
            }
        }
    }

    ListView {
        id: list

        anchors.top: header.bottom
        anchors.topMargin: Theme.space(2)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        model: Notifs.groups
        spacing: Theme.space(2)
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        cacheBuffer: 400

        delegate: NotificationGroup {
            required property var modelData

            width: list.width
            group: modelData
        }

        /*
         * Groups are plain JS objects rebuilt whenever the list changes, so the
         * view resets rather than being told which row moved — add and remove
         * transitions cannot run across a reset. The card fades as a whole
         * instead, which is honest about what actually happened.
         */
        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

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
        anchors.centerIn: list
        dim: true
        text: "nothing to show"
        visible: !Notifs.any
    }
}
