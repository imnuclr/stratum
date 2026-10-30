import QtQuick
import qs.services
import qs.theme

/*
 * One notification. The app and the age sit on the header line, the summary and
 * body beneath — the sender matters more than the title for deciding whether to
 * read it, so it leads.
 *
 * The whole row is the way into the application: clicking it invokes whatever
 * the sender offered, or brings that application forward. Dismissing is a
 * separate target in the corner, always drawn, because a close affordance that
 * only appears on hover cannot be found by someone looking for it — and on a
 * page whose entire purpose is reading and clearing, that is the one control
 * that has to be obvious.
 */
Rectangle {
    id: root

    required property var notification

    readonly property var extraActions: (root.notification?.actions ?? [])
        .filter(a => a.identifier !== "default")

    implicitHeight: content.implicitHeight + Theme.space(3) * 2

    radius: Theme.rTile
    color: hover.hovered ? Qt.lighter(Theme.deep, 3) : Theme.deep
    border.width: 1
    border.color: hover.hovered ? Theme.fg : Theme.outline

    Behavior on color {
        ColorAnimation {
            duration: Theme.micro
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.micro
        }
    }

    Column {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space(3)
        spacing: Theme.space(1)

        Item {
            width: parent.width
            height: app.implicitHeight

            SectionLabel {
                id: app

                anchors.left: parent.left
                anchors.right: dismiss.left
                anchors.rightMargin: Theme.space(2)
                elide: Text.ElideRight
                color: Theme.fgBright
                text: `${root.notification?.appName ?? "system"} · ${Notifs.age(root.notification)}`
            }

            // Always drawn, dim until pointed at. The target is larger than the
            // glyph so it can be hit without aiming.
            Item {
                id: dismiss

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.space(4)
                height: Theme.space(4)

                Glyph {
                    anchors.centerIn: parent
                    name: "close"
                    size: 14
                    color: closeHover.hovered ? Theme.fg : Theme.fgDim

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.micro
                        }
                    }
                }

                HoverHandler {
                    id: closeHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Notifs.dismiss(root.notification)
                }
            }
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.notification?.summary ?? ""
            visible: text.length > 0
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 16
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            // Senders are allowed limited markup, and the server advertises
            // support for it, so it has to be rendered rather than shown raw.
            textFormat: Text.StyledText
            text: root.notification?.body ?? ""
            visible: text.length > 0
            color: Theme.fgBright
            font.family: Theme.fontUi
            font.pixelSize: 14
            renderType: Text.NativeRendering
        }

        // Anything the sender offered beyond the default, as its own target.
        Row {
            spacing: Theme.space(2)
            visible: root.extraActions.length > 0

            Repeater {
                model: root.extraActions

                SectionLabel {
                    required property var modelData

                    text: modelData.text
                    color: actionHover.hovered ? Theme.fg : Theme.fgBright

                    HoverHandler {
                        id: actionHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: modelData.invoke()
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    // Below the dismiss target and the action labels in the stack, so those win.
    TapHandler {
        onTapped: Notifs.activate(root.notification)
    }
}
