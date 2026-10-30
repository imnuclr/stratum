import QtQuick
import qs.theme

/*
 * A scrolling settings page: a header, then cards. Pages put their cards
 * straight inside; spacing and width are handled here.
 */
Flickable {
    id: root

    property alias icon: header.icon
    property alias title: header.title
    property alias detail: header.detail
    default property alias cards: stack.data

    contentHeight: column.implicitHeight + Theme.space(6)
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column

        width: root.width - Theme.space(2)
        spacing: Theme.space(5)

        PageHeader {
            id: header

            width: parent.width
        }

        Column {
            id: stack

            width: parent.width
            spacing: Theme.space(5)

            onChildrenChanged: {
                for (const child of stack.children)
                    child.width = Qt.binding(() => stack.width);
            }
        }
    }
}
