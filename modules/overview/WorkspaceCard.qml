import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * One workspace, drawn to the shape of the monitor it lives on, with its windows
 * placed where they actually are. A grid of thumbnails would lose the thing an
 * overview is for — knowing which window is where without reading any labels.
 */
Item {
    id: root

    required property int wsId
    required property real cardWidth
    // The screen this card is drawn on, used only until the workspace says which
    // monitor it actually belongs to.
    required property var monitor

    readonly property var workspace: Hypr.workspaces.find(w => w.id === root.wsId) ?? null

    /*
     * A workspace belongs to a monitor, and window coordinates are
     * desktop-absolute. Measuring every card against the screen the overview
     * happens to be drawn on put the windows of workspaces living on the other
     * monitor thousands of pixels off to one side, clipped out of their own card
     * — the count said "1 window" and the card looked empty.
     */
    readonly property var home: workspace?.monitor ?? root.monitor
    readonly property var clients: workspace?.toplevels?.values ?? []
    readonly property bool active: Hypr.focusedWorkspace?.id === root.wsId
    readonly property bool occupied: clients.length > 0

    // The monitor's own aspect, so a window keeps its shape inside the card.
    readonly property real aspect: home ? home.height / home.width : 9 / 16
    readonly property real fit: cardWidth / (home?.width ?? 1920)

    implicitWidth: cardWidth
    implicitHeight: frame.height + label.height + Theme.space(2)

    Rectangle {
        id: frame

        width: parent.width
        height: Math.round(parent.width * root.aspect)
        radius: Theme.rTile
        color: Theme.surface
        clip: true
        border.width: 1
        border.color: root.active ? Theme.accent : Theme.line

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.micro
            }
        }

        // An empty workspace says so rather than looking like a failed render.
        DotField {
            anchors.centerIn: parent
            visible: !root.occupied
            rows: 3
            cell: 7
            dotSize: 2.4
            // A flat row of unlit dots: DotField takes its column count from the
            // values it is handed.
            values: new Array(7).fill(0)
            opacity: 0.5
        }

        Repeater {
            model: root.clients

            WindowTile {
                required property var modelData

                client: modelData
                fit: root.fit
                // Workspace coordinates are desktop-absolute, so a monitor that
                // is not at the origin offsets every window on it.
                originX: root.home?.x ?? 0
                originY: root.home?.y ?? 0
            }
        }

        MouseArea {
            anchors.fill: parent
            // Below the tiles, so clicking a window focuses that window and
            // clicking the space around it just goes to the workspace.
            z: -1
            onClicked: {
                Hypr.focusWorkspace(root.wsId);
                Shell.close();
            }
        }
    }

    Row {
        id: label

        anchors.top: frame.bottom
        anchors.topMargin: Theme.space(2)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.space(2)

        DotText {
            text: `${root.wsId}`
            size: 13
            color: root.active ? Theme.accent : (root.occupied ? Theme.fg : Theme.fgFaint)
            plain: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.occupied
            text: root.clients.length === 1 ? "1 window" : `${root.clients.length} windows`
            color: Theme.fgFaint
            font.family: Theme.fontUi
            font.pixelSize: 10
            font.letterSpacing: 1
            renderType: Text.NativeRendering
        }
    }
}
