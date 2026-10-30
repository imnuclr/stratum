import QtQuick
import qs.services
import qs.theme

/*
 * One setting: what it is and what it does on the left, its control on the right.
 * The detail line is for the consequence, not a restatement of the title — if it
 * would only repeat the title it should be left empty.
 */
Item {
    id: root

    property string title: ""
    property string detail: ""
    // The hairline under the row; a card turns it off on its last row.
    property bool divider: true
    default property alias control: slot.data

    // The row's own height, and whatever an unfolding control (a Dropdown)
    // adds beneath its first line while open.
    readonly property real extra: slot.children.length > 0 ? (slot.children[0].extra ?? 0) : 0
    readonly property real base: Math.max(52, copy.implicitHeight + Theme.space(3) * 2,
        slot.height - root.extra + Theme.space(3) * 2)

    implicitHeight: root.base + root.extra

    /*
     * Brought into view and flashed when settings search chose it. The page
     * may still be loading when the choice is made, so this is asked on
     * creation as well as on change.
     */
    readonly property bool sought: Shell.settingsFocus.length > 0 && Shell.settingsFocus.toLowerCase() === String(root.title).toLowerCase()

    onSoughtChanged: if (sought) Qt.callLater(root.reveal)
    Component.onCompleted: if (sought) revealLater.restart()

    Timer {
        id: revealLater

        interval: 120
        onTriggered: root.reveal()
    }

    function reveal() {
        if (!root.sought || !root.visible)
            return;
        let p = root.parent;
        while (p && p.contentY === undefined)
            p = p.parent;
        if (p) {
            const y = root.mapToItem(p.contentItem, 0, 0).y - 32;
            p.contentY = Math.max(0, Math.min(y, p.contentHeight - p.height));
        }
        flash.restart();
        Shell.settingsFocus = "";
    }

    Rectangle {
        id: glow

        anchors.fill: parent
        anchors.leftMargin: -Theme.space(2)
        anchors.rightMargin: -Theme.space(2)
        radius: Theme.rInner
        color: Theme.accent
        opacity: 0
        z: -1

        SequentialAnimation {
            id: flash

            NumberAnimation { target: glow; property: "opacity"; to: 0.28; duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: Theme.smooth }
            PauseAnimation { duration: 500 }
            NumberAnimation { target: glow; property: "opacity"; to: 0; duration: 900; easing.type: Easing.Bezier; easing.bezierCurve: Theme.smooth }
        }
    }

    Column {
        id: copy

        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: Theme.space(4)
        anchors.top: parent.top
        anchors.topMargin: (root.base - implicitHeight) / 2
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 14
            font.weight: Font.Medium
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            visible: root.detail.length > 0
            text: root.detail
            color: Theme.fgDim
            font.family: Theme.fontUi
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }

    Item {
        id: slot

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: (root.base - (height - root.extra)) / 2
        width: childrenRect.width
        height: childrenRect.height
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.line
        visible: root.divider
    }
}
