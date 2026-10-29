import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.theme

/*
 * App icon and title of the focused window. Collapses to nothing when the
 * workspace is empty, so the island shrinks rather than showing a stale title.
 */
Row {
    id: root

    readonly property var toplevel: Hypr.activeToplevel
    readonly property string appClass: toplevel?.lastIpcObject?.class ?? ""
    readonly property string windowTitle: toplevel?.title ?? ""
    readonly property bool present: windowTitle.length > 0

    // Themed icon by app class, which matches for most apps; Glyph covers the rest.
    readonly property string iconPath: appClass.length > 0 ? Quickshell.iconPath(appClass, true) : ""

    spacing: Theme.space(1)
    visible: present

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 15
        height: 15

        Image {
            anchors.fill: parent
            source: root.iconPath
            visible: root.iconPath.length > 0
            sourceSize.width: 30
            sourceSize.height: 30
            smooth: true
            asynchronous: true
        }

        Glyph {
            anchors.centerIn: parent
            name: "app"
            size: 14
            color: Theme.fgDim
            visible: root.iconPath.length === 0
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        // Long titles are cut rather than allowed to push the island wide enough
        // to collide with the centre clock.
        width: Math.min(implicitWidth, 320)
        elide: Text.ElideRight
        text: root.windowTitle
        color: Theme.fgDim
        font.family: Theme.fontUi
        font.pixelSize: 13
        renderType: Text.NativeRendering
    }
}
