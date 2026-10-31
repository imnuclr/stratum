import QtQuick
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

/*
 * A picture from the wallpaper folder, as dots or as it is, changing on its own.
 */
Item {
    id: root

    property var item: ({})
    property bool live: true

    readonly property bool dotted: Widgets.option(root.item, "look") !== "plain"
    readonly property string every: Widgets.option(root.item, "every")

    property string path: ""

    function pick() {
        const list = Wallpaper.entries;
        if (list.length > 0)
            root.path = list[Math.floor(Math.random() * list.length)];
    }

    Component.onCompleted: root.pick()

    Connections {
        target: Wallpaper

        function onEntriesChanged() {
            if (root.path.length === 0)
                root.pick();
        }
    }

    Timer {
        running: root.live && root.every !== "never"
        repeat: true
        interval: root.every === "day" ? 86400000 : 3600000
        onTriggered: root.pick()
    }

    DotImage {
        anchors.fill: parent
        anchors.margins: Theme.space(3)
        visible: root.dotted
        source: root.dotted && root.path.length > 0 ? `file://${root.path}` : ""
        cell: 5
        dotScale: 0.48
        halftone: true
        colored: true
        fit: "crop"
    }

    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: Theme.space(2)
        radius: Theme.rTile - Theme.space(2)
        color: "transparent"
        visible: !root.dotted

        Image {
            anchors.fill: parent
            source: !root.dotted && root.path.length > 0 ? `file://${root.path}` : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 600
            asynchronous: true
        }
    }
}
