pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

/*
 * The frozen frame behind a region selection.
 *
 * Shown only on the monitor that was grabbed, and torn down (not just hidden)
 * afterwards, so the next freeze loads its own image rather than reusing the
 * last one. Takes no input: the selector above it needs every click.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        readonly property bool frozen: Screenshot.freezeOutput === win.modelData.name

        screen: modelData
        visible: win.frozen
        color: "black"
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
