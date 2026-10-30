import QtQuick
import Quickshell.Hyprland
import qs.theme

/*
 * A short drift when the workspace changes, and nothing at rest.
 *
 * `pulse` is a signed distance in pixels: it leans against the direction of travel
 * as the workspace changes and eases back to zero, so the wallpaper is always
 * centred once things settle. An earlier version mapped the workspace number to a
 * fixed offset, which left the picture permanently off to one side on the first
 * and last workspaces.
 */
Item {
    id: root

    required property var monitor
    // How far the nearest layer leans, in pixels.
    property real depth: 70

    property real pulse: 0

    readonly property int workspace: Hyprland.monitorFor(root.monitor)?.activeWorkspace?.id ?? 1
    property int last: 1

    Component.onCompleted: root.last = root.workspace

    onWorkspaceChanged: {
        const dir = Math.sign(root.workspace - root.last);
        root.last = root.workspace;
        if (dir === 0)
            return;
        kick.stop();
        kick.peak = -dir * root.depth;
        kick.restart();
    }

    SequentialAnimation {
        id: kick

        property real peak: 0

        NumberAnimation {
            target: root
            property: "pulse"
            to: kick.peak
            duration: Theme.sheetMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft
        }

        NumberAnimation {
            target: root
            property: "pulse"
            to: 0
            duration: Math.round(Theme.sheetMs * 2.2)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft
        }
    }
}
