import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * One notification. The app and the age sit on the header line, the summary and
 * body beneath — the sender matters more than the title for deciding whether to
 * read it, so it leads.
 */
Rectangle {
    id: root

    required property var notification

    implicitHeight: content.implicitHeight + Theme.space(3) * 2

    radius: Theme.rTile
    color: hover.hovered ? Theme.surfaceTop : Theme.surfaceHi

    Behavior on color {
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
                text: `${root.notification?.appName ?? "system"} · ${Notifs.age(root.notification)}`
            }

            // Only on hover: a row of permanent close buttons turns the list into
            // a toolbar, and the whole row is dismissable anyway.
            Glyph {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                name: "close"
                size: 14
                color: Theme.fgBright
                opacity: hover.hovered ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.micro
                    }
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
            font.pixelSize: 15
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
            color: Theme.fgDim
            font.family: Theme.fontUi
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }
    }

    HoverHandler {
        id: hover
    }
}
