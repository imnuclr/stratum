pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
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
        // Amount is how fine the grid is, size how much of each cell a dot fills.
        readonly property real dotCell: 4 + (1 - Config.get("wallpaper.dotAmount", 0.8)) * 20
        readonly property real dotScale: Config.get("wallpaper.dotScale", 0.5)
        readonly property real light: Config.get("wallpaper.light", 1)

        screen: modelData
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "stratum-background"
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // Takes the pointer, for holding on the wallpaper (below). Windows sit above
        // this layer, so only bare desktop reaches it.

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        color: Theme.bg

        // Hold on the bare desktop for a moment and the wallpaper picker opens.
        Item {
            anchors.fill: parent
            z: 100

            TapHandler {
                longPressThreshold: 0.6
                onLongPressed: {
                    Shell.open("picker", win.modelData.name);
                }
            }
        }

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
        // A layer, not an Image: the layers are WallLayer items and a typed property
        // rejects them, which stopped a wallpaper that arrived after startup from
        // ever being set.
        property var pending: null
        property bool topIsA: true
        property string queued: ""

        function show(url) {
            if (fade.running) {
                // A switch during a fade waits for it to finish and only the latest
                // is kept. Cutting the fade short jumped it to full in one frame,
                // which is a hard cut whenever wallpapers are changed quickly.
                win.queued = url.toString();
                return;
            } else if (win.pending) {
                // The last one has not been drawn yet, so nothing is showing it:
                // change what it will show rather than starting another behind it.
                win.pending.source = url;
                return;
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
            if (win.wanted === current.source) {
                win.queued = "";
                return;
            }
            win.show(win.wanted);
        }

        Component.onCompleted: {
            layerA.opacity = 1;
            layerA.source = win.wanted;
        }

        // Leans a little as the workspace changes, less than the subject does, so
        // the two read as being at different distances. Scaled up enough that its
        // edges never come into view, and back at the centre once it settles.
        readonly property bool drift: Config.get("wallpaper.parallax", true)

        WorkspaceDrift {
            id: lean

            monitor: win.modelData
            depth: Config.get("wallpaper.parallaxDepth", 70)
        }

        Item {
            id: stage

            anchors.fill: parent
            scale: win.drift ? Config.get("wallpaper.parallaxScale", 1.08) : 1
            x: win.drift ? lean.pulse * 0.4 : 0

            Behavior on x {
                NumberAnimation {
                    duration: Theme.sheetMs * 1.6
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            WallLayer {
                id: layerA

                anchors.fill: parent
                opacity: 0
                pixelWidth: win.modelData.width
                pixelHeight: win.modelData.height
                look: win.look
                mono: win.mono
                dotSize: win.dotCell
                dotScale: win.dotScale
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
                dotSize: win.dotCell
                dotScale: win.dotScale
                light: win.light

                onReady: {
                    if (win.pending === layerB) {
                        fade.target = layerB;
                        fade.restart();
                    }
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
                if (win.queued.length > 0) {
                    const next = win.queued;
                    win.queued = "";
                    const top = win.topIsA ? layerA : layerB;
                    if (next !== top.source.toString())
                        win.show(next);
                }
            }
        }
    }
}
