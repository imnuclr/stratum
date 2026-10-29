import QtQuick
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

/*
 * One window inside a workspace card, placed where it actually is.
 *
 * The thumbnail is a still rather than a live stream: a live capture of every
 * window on screen runs at full resolution every frame, which costs more than an
 * overview is worth. It is taken while the overview is open and dropped when it
 * closes.
 */
Rectangle {
    id: root

    required property var client
    // Pixels per compositor pixel, and where the workspace's own origin sits, so
    // a window's real geometry maps into the card.
    required property real fit
    required property real originX
    required property real originY

    readonly property var ipc: client?.lastIpcObject ?? null
    readonly property bool focused: Hypr.activeToplevel === client

    x: Math.round(((ipc?.at?.[0] ?? 0) - originX) * fit)
    y: Math.round(((ipc?.at?.[1] ?? 0) - originY) * fit)
    width: Math.max(2, Math.round((ipc?.size?.[0] ?? 0) * fit))
    height: Math.max(2, Math.round((ipc?.size?.[1] ?? 0) * fit))

    radius: Theme.rInner
    color: Theme.surfaceHi
    clip: true
    border.width: 1
    border.color: root.focused ? Theme.accent : (hover.hovered ? Theme.fgFaint : Theme.line)

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.micro
        }
    }

    ScreencopyView {
        id: view

        anchors.fill: parent
        captureSource: root.client?.wayland ?? null
        live: false

        /*
         * constraintSize is a bounding box for a letterboxed fit, not a stretch
         * target, so the capture keeps its own aspect ratio and leaves padding
         * inside a tile shaped differently to the window. The tile is already
         * the window's true shape, so the two agree and the scale below is
         * normally 1 — it only does anything while a capture is still settling.
         */
        constraintSize.width: root.width
        constraintSize.height: root.height

        // Transient width/height before a capture loads are wild enough that
        // scaling against them produces a tiled-looking stretch.
        readonly property bool ready: hasContent && width > 1 && height > 1

        transform: Scale {
            xScale: view.ready ? root.width / view.width : 1
            yScale: view.ready ? root.height / view.height : 1
        }
    }

    // Stands in for a window whose capture has not arrived, and names the app
    // either way once the tile is big enough to read.
    Text {
        anchors.centerIn: parent
        width: parent.width - Theme.space(2)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        visible: !view.hasContent && parent.width > 48
        text: (root.ipc?.class ?? "").toUpperCase()
        color: Theme.fgDim
        font.family: Theme.fontUi
        font.pixelSize: 10
        font.letterSpacing: 1
        renderType: Text.NativeRendering
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: {
            Hypr.focusWindow(root.ipc?.address ?? root.client?.address ?? "");
            Shell.close();
        }
    }
}
