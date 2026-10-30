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

        // How the picture is drawn: as it is or as dots, in colour or without.
        readonly property string look: Config.get("wallpaper.look", "original")
        readonly property bool mono: Config.get("wallpaper.mono", false)
        readonly property real dotSize: Config.get("wallpaper.dotSize", 8)
        readonly property real light: Config.get("wallpaper.light", 1)

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
         * Two layers that trade places, so the picture on screen is never touched.
         *
         * Handing the outgoing image to a second Image by assigning its source
         * made that Image load it from disk again — asynchronously, uncached — and
         * for those few frames the back layer was empty, which showed as a flash
         * of the plain background at the moment of switching. Here the visible
         * layer stays exactly as it is. The other one loads the new file at
         * opacity 0 above it, fades in once it has something to show, and only
         * when it fully covers the old one is the old one emptied.
         */
        property Image pending: null
        property bool topIsA: true

        function show(url) {
            // A switch during a fade: let the unfinished one land, then go again.
            if (fade.running) {
                fade.stop();
                if (win.pending)
                    win.pending.opacity = 1;
            }
            const incoming = win.topIsA ? layerB : layerA;
            const outgoing = win.topIsA ? layerA : layerB;
            incoming.opacity = 0;
            incoming.z = 2;
            outgoing.z = 1;
            win.pending = incoming;
            win.topIsA = !win.topIsA;
            incoming.source = url;
        }

        onWantedChanged: {
            const current = win.topIsA ? layerA : layerB;
            if (win.wanted === current.source)
                return;
            win.show(win.wanted);
        }

        Component.onCompleted: {
            layerA.opacity = 1;
            layerA.source = win.wanted;
        }

        WallLayer {
            id: layerA

            anchors.fill: parent
            opacity: 0
            pixelWidth: win.modelData.width
            pixelHeight: win.modelData.height
            look: win.look
            mono: win.mono
            dotSize: win.dotSize
            light: win.light

            onReady: {
                if (win.pending === layerA) {
                    fade.target = layerA;
                    fade.restart();
                }
            }
        }

        WallLayer {
            id: layerB

            anchors.fill: parent
            opacity: 0
            pixelWidth: win.modelData.width
            pixelHeight: win.modelData.height
            look: win.look
            mono: win.mono
            dotSize: win.dotSize
            light: win.light

            onReady: {
                if (win.pending === layerB) {
                    fade.target = layerB;
                    fade.restart();
                }
            }
        }

        NumberAnimation {
            id: fade

            property: "opacity"
            to: 1
            duration: Config.get("wallpaper.fadeMs", 350)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft

            // Freeing the outgoing image only once it is fully covered.
            onFinished: {
                const old = win.topIsA ? layerB : layerA;
                old.source = "";
                win.pending = null;
            }
        }
    }
}
