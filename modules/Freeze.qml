pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

/*
 * The frozen frame behind a region selection.
 *
 * The window stays mapped, empty and transparent, the whole time. A window that
 * is created when the key is pressed gets Hyprland's layer-open animation — the
 * frozen frame slid down from the top of the screen, so the freeze itself was
 * visible. Already mapped, the image simply appears in place. Only the grabbed
 * monitor's loader is active, and it is torn down afterwards so the next freeze
 * loads its own image rather than reusing the last. Takes no input: the selector
 * above it needs every click.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        readonly property bool frozen: Screenshot.freezeOutput === win.modelData.name

        screen: modelData
        visible: true
        color: "transparent"
        mask: Region {}

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "stratum-freeze"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Loader {
            anchors.fill: parent
            active: win.frozen

            sourceComponent: Image {
                source: Screenshot.freezeSource
                fillMode: Image.Stretch
                smooth: false
                cache: false
                asynchronous: false

                onStatusChanged: {
                    if (status === Image.Ready)
                        Screenshot.freezeShown();
                }
            }
        }
    }
}
