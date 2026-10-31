import QtQuick
import qs.services
import qs.theme

/*
 * Settings that belong together, on one rounded card with an optional title
 * above it — the way a group reads at a glance instead of as one long list.
 * The last row's hairline is dropped, since the card's own edge ends it.
 */
Column {
    id: root

    property string title: ""
    property string footnote: ""
    default property alias rows: list.data

    spacing: Theme.space(2)

    SectionLabel {
        visible: root.title.length > 0
        leftPadding: Theme.space(1)
        text: root.title
    }

    Rectangle {
        width: root.width
        height: list.implicitHeight + Theme.space(1) * 2
        radius: Theme.rTile
        color: Theme.surfaceHi
        border.width: 1
        border.color: Theme.line

        Column {
            id: list

            x: Theme.space(4)
            y: Theme.space(1)
            width: parent.width - Theme.space(4) * 2

            onChildrenChanged: Qt.callLater(root.tidy)
            Component.onCompleted: root.tidy()
        }
    }

    Text {
        visible: root.footnote.length > 0
        width: root.width
        leftPadding: Theme.space(1)
        text: root.footnote
        color: Theme.fgFaint
        font.family: Theme.fontUi
        font.pixelSize: 12
        wrapMode: Text.WordWrap
        renderType: Text.NativeRendering
    }

    // Scrolled to when settings search picks it by its title.
    readonly property bool sought: root.title.length > 0 && Shell.settingsFocus.length > 0
        && Shell.settingsFocus.toLowerCase() === root.title.toLowerCase()

    onSoughtChanged: if (sought) Qt.callLater(root.reveal)
    Component.onCompleted: if (sought) Qt.callLater(root.reveal)

    function reveal() {
        if (!root.sought)
            return;
        let p = root.parent;
        while (p && p.contentY === undefined)
            p = p.parent;
        if (p) {
            const y = root.mapToItem(p.contentItem, 0, 0).y - 24;
            p.contentY = Math.max(0, Math.min(y, p.contentHeight - p.height));
        }
        Shell.settingsFocus = "";
    }

    function tidy() {
        let last = null;
        for (const child of list.children) {
            if (child.width !== undefined && child.divider !== undefined) {
                child.width = Qt.binding(() => list.width);
                child.divider = true;
                if (child.visible)
                    last = child;
            }
        }
        if (last)
            last.divider = false;
    }
}
