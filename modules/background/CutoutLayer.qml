pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services
import qs.theme

/*
 * The wallpaper's subject, on a layer of its own above the wallpaper.
 *
 * It sits in the same place as the picture behind it, cropped the same way, so at
 * rest the two are one image. It moves further than the picture when the
 * workspace changes, which is what makes the subject read as nearer.
 *
 * Skipped for the dotted look: a second grid of dots over the first would not
 * line up with it, and the subject is already in the dots.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        readonly property string url: Cutout.urlFor(win.modelData.name)
        readonly property bool shown: win.url.length > 0
            && Config.get("wallpaper.look", "original") === "original"
            && Config.get("wallpaper.parallax", true)

        screen: modelData
        visible: true
        color: "transparent"
        mask: Region {}
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "stratum-cutout"

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        WorkspaceDrift {
            id: lean

            monitor: win.modelData
            depth: Config.get("wallpaper.parallaxDepth", 70)
        }

        Item {
            id: stage

            anchors.fill: parent
            scale: Config.get("wallpaper.parallaxScale", 1.08)
            x: lean.pulse
            opacity: win.shown && picture.status === Image.Ready ? 1 : 0

            Behavior on x {
                NumberAnimation {
                    duration: Theme.sheetMs * 1.6
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.sheetMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            Image {
                id: picture

                anchors.fill: parent
                source: win.shown ? win.url : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: win.modelData.width
                sourceSize.height: win.modelData.height
                asynchronous: true
                cache: false
            }
        }
    }
}
