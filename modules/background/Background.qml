pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.theme

/*
 * The wallpaper, as the bottom layer of the shell's own stack.
 *
 * Two images rather than one, because changing a single image's source swaps it
 * on the frame the file finishes loading — a hard cut, and on a large JPEG a
 * visible stall. The outgoing image stays on the back while the incoming one
 * loads out of sight, and only once it is actually ready does it fade over the
 * top. Same rule as the popouts: nothing is shown before it has something to
 * show.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        readonly property url wanted: Wallpaper.urlFor(win.modelData.name)

        screen: modelData
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "stratum-background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // Nothing here is interactive; the desktop below must still get clicks.
        mask: Region {}

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: Theme.bg

        /*
         * The front image's source is assigned, never bound.
         *
         * A binding on it would re-evaluate on the same change that runs this
         * handler, with no guaranteed order between them: if the binding wins,
         * the line below hands the back layer the image that is already on the
         * front and there is nothing to fade from — a cut. Assigning both here
         * keeps the two in the order they have to happen in.
         */
        onWantedChanged: {
            if (win.wanted === front.source)
                return;
            back.source = front.source;
            front.opacity = 0;
            front.source = win.wanted;
        }

        Component.onCompleted: front.source = win.wanted

        Image {
            id: back

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            // Cropped to this monitor rather than scaled to a common size: the
            // 3440x1440 and the 1920x1080 want different parts of the same file.
            sourceSize.width: win.modelData.width
            sourceSize.height: win.modelData.height
            asynchronous: true
            cache: false
        }

        Image {
            id: front

            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: win.modelData.width
            sourceSize.height: win.modelData.height
            asynchronous: true
            cache: false

            opacity: 0

            onStatusChanged: {
                if (front.status === Image.Ready)
                    reveal.restart();
            }

            NumberAnimation {
                id: reveal

                target: front
                property: "opacity"
                to: 1
                duration: Config.get("wallpaper.fadeMs", 600)
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.gentle

                // Freeing the outgoing image only once it is fully covered.
                onFinished: back.source = ""
            }
        }
    }
}
