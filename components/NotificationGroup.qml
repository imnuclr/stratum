import QtQuick
import Quickshell
import qs.services
import qs.theme

/*
 * Every notification from one app, as a single card.
 *
 * Ten pings from one chat are one thing that happened, not ten. Flat, the
 * noisiest app buries everything else; folded, each app costs one header and
 * its backlog sits underneath, so a quiet app is still visible next to a loud
 * one. The header carries the app's picture, its name, how long ago it last
 * spoke, and how many are inside.
 *
 * Collapsed by default past a handful, because the point of folding is that a
 * backlog of forty does not push everything else off the screen. The count is
 * the control: click it to see the rest.
 */
Rectangle {
    id: root

    required property var group

    property int collapsedCount: 5
    property bool expanded: false

    readonly property var items: root.group?.items ?? []
    readonly property int total: root.items.length
    readonly property bool foldable: root.total > root.collapsedCount
    readonly property var visibleItems: root.expanded || !root.foldable
        ? root.items
        : root.items.slice(0, root.collapsedCount)

    readonly property var newest: root.items.length > 0 ? root.items[root.items.length - 1] : null
    readonly property bool critical: root.items.some(n => Notifs.isCritical(n))

    // The app's own icon, taken from the most recent notification it sent.
    readonly property string appIcon: Notifs.iconFor(root.newest, true)

    implicitHeight: body.implicitHeight + Theme.space(3) * 2
    radius: Theme.rTile
    color: Theme.surfaceHi
    border.width: 1
    border.color: root.critical ? Theme.accent : Theme.outline

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.standard
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.smooth
        }
    }

    Column {
        id: body

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space(3)
        spacing: Theme.space(2)

        Item {
            id: header

            width: parent.width
            height: Math.max(avatar.height, appName.implicitHeight)

            /*
             * The whole header folds the group, not just the count. The count
             * is the thing that *looks* clickable, but it is a small target and
             * people reach for the app's name — so the name works too, and the
             * badge stays as the thing that says it can be done at all.
             */
            HoverHandler {
                id: headerHover

                enabled: root.foldable
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: root.foldable
                onTapped: root.expanded = !root.expanded
            }

            DotAvatar {
                id: avatar

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                size: 38
                source: root.appIcon
                name: root.group?.app ?? ""
                ringColor: root.critical ? Theme.accent : Theme.fgFaint
            }

            Text {
                id: appName

                anchors.left: avatar.right
                anchors.leftMargin: Theme.space(2)
                anchors.right: age.left
                anchors.rightMargin: Theme.space(2)
                anchors.verticalCenter: parent.verticalCenter

                text: root.group?.app ?? "system"
                elide: Text.ElideRight
                color: root.critical ? Theme.accent : Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.variableAxes: ({ "wght": 500 })
                renderType: Text.NativeRendering
            }

            SectionLabel {
                id: age

                anchors.right: count.left
                anchors.rightMargin: Theme.space(2)
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.age(root.newest)
            }

            /*
             * The count, and the control that opens the rest. It is the only
             * thing in the header worth clicking, so it is the only thing drawn
             * as clickable.
             */
            Rectangle {
                id: count

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                width: countRow.implicitWidth + Theme.space(2)
                height: countRow.implicitHeight + Theme.space(1)
                radius: height / 2
                visible: root.total > 1

                color: countHover.hovered ? Theme.surfaceTop : Qt.alpha(Theme.fg, 0.1)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Row {
                    id: countRow

                    anchors.centerIn: parent
                    spacing: Theme.space(1)

                    SectionLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.total
                        color: Theme.fgBright
                    }

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.foldable
                        name: "chevron-down"
                        size: 11
                        color: Theme.fgBright
                        rotation: root.expanded ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Theme.standard
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.smooth
                            }
                        }
                    }
                }

                HoverHandler {
                    id: countHover

                    cursorShape: root.foldable ? Qt.PointingHandCursor : Qt.ArrowCursor
                }

                TapHandler {
                    enabled: root.foldable
                    onTapped: root.expanded = !root.expanded
                }
            }
        }

        // The notifications themselves, one compact line each.
        Column {
            width: parent.width
            spacing: Theme.space(1)

            Repeater {
                model: root.visibleItems

                NotificationLine {
                    required property var modelData

                    width: parent.width
                    notification: modelData
                }
            }
        }

        SectionLabel {
            dim: true
            visible: root.foldable && !root.expanded
            text: `${root.total - root.collapsedCount} more`
        }
    }
}
