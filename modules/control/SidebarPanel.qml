import QtQuick
import qs.components
import qs.modules.notifications
import qs.services
import qs.theme

/*
 * The top of the sidebar: notifications and the to-do list, one at a time.
 *
 * They share the room above the controls and switch between each other, so a
 * list of tasks does not push the controls up the panel. The tabs are drawn as
 * a segmented control rather than two caps labels that merely changed colour:
 * there was nothing saying the second one was a target at all.
 */
Item {
    id: root

    // Which menu is showing. On Shell so a trackpad swipe can move it too, and
    // so it survives the sheet being rebuilt per monitor.
    readonly property int tab: Shell.sidebarTab

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28

        Rectangle {
            id: tabBar

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: tabs.implicitWidth + 4
            height: 28
            radius: height / 2
            color: Theme.surfaceHi

            Row {
                id: tabs

                anchors.centerIn: parent
                spacing: 2

                Rectangle {
                    id: notificationsTab

                    width: notificationsRow.implicitWidth + Theme.space(3) * 2
                    height: 24
                    radius: height / 2
                    color: root.tab === 0
                        ? Theme.fg
                        : (notifHover.hovered ? Theme.surfaceTop : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.standard
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.smooth
                        }
                    }

                    Row {
                        id: notificationsRow

                        anchors.centerIn: parent
                        spacing: Notifs.any ? Theme.space(2) : 0

                        SectionLabel {
                            text: "notifications"
                            color: root.tab === 0 ? Theme.bg : Theme.fgDim

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.standard
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.smooth
                                }
                            }
                        }

                        /*
                         * The count keeps the accent for Critical only: a number
                         * that is always coloured says nothing. On the filled
                         * tab it takes the sheet colour instead of white, which
                         * would vanish against the fill.
                         */
                        Rectangle {
                            visible: Notifs.any
                            width: Notifs.any ? Math.max(height, countLabel.implicitWidth + Theme.space(2)) : 0
                            height: Notifs.any ? countLabel.implicitHeight + 2 : 0
                            radius: height / 2
                            color: Notifs.anyCritical
                                ? Theme.accent
                                : (root.tab === 0 ? Qt.alpha(Theme.bg, 0.14) : Qt.alpha(Theme.fg, 0.12))

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
                                color: Notifs.anyCritical
                                    ? Theme.bg
                                    : (root.tab === 0 ? Theme.fg : Theme.fgBright)
                            }
                        }
                    }

                    HoverHandler {
                        id: notifHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: Shell.sidebarTab = 0
                    }
                }

                Rectangle {
                    id: notesTab

                    width: notesRow.implicitWidth + Theme.space(3) * 2
                    height: 24
                    radius: height / 2
                    color: root.tab === 1
                        ? Theme.fg
                        : (notesHover.hovered ? Theme.surfaceTop : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.standard
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.smooth
                        }
                    }

                    Row {
                        id: notesRow

                        anchors.centerIn: parent
                        spacing: Notes.openCount > 0 ? Theme.space(2) : 0

                        SectionLabel {
                            text: "to-do"
                            color: root.tab === 1 ? Theme.bg : Theme.fgDim

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.standard
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.smooth
                                }
                            }
                        }

                        SectionLabel {
                            text: Notes.openCount > 0 ? Notes.openCount : ""
                            color: root.tab === 1 ? Theme.bg : Theme.fgFaint
                            opacity: 0.7
                        }
                    }

                    HoverHandler {
                        id: notesHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: Shell.sidebarTab = 1
                    }
                }
            }
        }

        SectionLabel {
            id: action

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: root.tab === 0 ? Notifs.any : Notes.doneCount > 0
            text: root.tab === 0 ? "clear all" : "clear done"
            color: actionHover.hovered ? Theme.accent : Theme.fgBright

            Behavior on color {
                ColorAnimation {
                    duration: Theme.micro
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

            HoverHandler {
                id: actionHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    if (root.tab === 0)
                        Notifs.clearAll();
                    else
                        Notes.clearDone();
                }
            }
        }
    }

    NotificationList {
        id: notifications

        anchors.top: header.bottom
        anchors.topMargin: Theme.space(3)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        // The tab is the heading now.
        heading: false

        opacity: root.tab === 0 ? 1 : 0
        enabled: root.tab === 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        transform: Translate {
            y: root.tab === 0 ? 0 : -Theme.space(2)

            Behavior on y {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }
        }
    }

    NotesPanel {
        id: notes

        anchors.top: header.bottom
        anchors.topMargin: Theme.space(3)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        opacity: root.tab === 1 ? 1 : 0
        enabled: root.tab === 1
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        transform: Translate {
            y: root.tab === 1 ? 0 : Theme.space(2)

            Behavior on y {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }
        }
    }
}
