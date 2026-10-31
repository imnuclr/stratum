pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * What to do with the screenshot just taken: a small bar at the foot of the
 * screen with the picture itself, and save or edit.
 *
 * Nothing has been saved at this point — the capture is on the clipboard and in
 * a temporary file — so leaving it alone throws it away, and the line along the
 * bottom shows how long that is. Pointing at it stops the clock.
 *
 * It arrives the way the volume indicator does: the picture lands first and the
 * bar opens out from it, so the eye starts on the thing being offered rather
 * than on a box that appeared. Leaving reverses it, faster.
 *
 * The same black-and-pale-outline shape as the volume indicator and the toasts,
 * on the same layer, but this one takes clicks: its mask is the bar.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        readonly property bool focused: Hypr.focusedWorkspace?.monitor?.name === win.modelData.name
        // On the screen being worked on: the picture is of that screen.
        readonly property bool up: Screenshot.offering && (win.focused || Quickshell.screens.length === 1)

        // 0 is away, 1 is the whole bar.
        property real p: 0
        // How far the contents have faded in: they follow the width, a little behind.
        readonly property real inside: Math.max(0, (win.p - 0.35) / 0.65)

        screen: modelData
        visible: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "stratum-shotbar"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 120

        onUpChanged: {
            open.to = win.up ? 1 : 0;
            open.duration = Math.max(1, (win.up ? 260 : 170) * Theme.speed);
            open.easing.bezierCurve = win.up ? Theme.expressive : Theme.smooth;
            open.restart();
        }

        NumberAnimation {
            id: open

            target: win
            property: "p"
            easing.type: Easing.Bezier
        }

        // Only the bar takes input; the rest of the strip is not there.
        mask: Region {
            item: win.p > 0.5 ? bar : null
        }

        Rectangle {
            id: bar

            // Shut, it is just the picture; open, the picture and the controls.
            readonly property real shutWidth: 56 + Theme.space(2) * 2
            readonly property real openWidth: row.implicitWidth + Theme.space(2) * 2

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space(6)
            width: bar.shutWidth + (bar.openWidth - bar.shutWidth) * win.p
            height: 52
            radius: 18
            color: Theme.deep
            border.width: 1
            border.color: Theme.outline
            opacity: Math.min(1, win.p * 2.5)
            visible: win.p > 0.01
            scale: 0.9 + 0.1 * win.p
            clip: true

            // Pointing at it stops the clock; the bar waits as long as you do.
            HoverHandler {
                id: hover

                onHoveredChanged: {
                    if (win.up || !hovered)
                        Screenshot.held = hovered;
                }
            }

            Row {
                id: row

                anchors.left: parent.left
                anchors.leftMargin: Theme.space(2)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space(2)

                // The capture itself, so there is no doubt what is being kept.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 56
                    height: 36
                    radius: 10
                    color: Theme.surfaceHi
                    clip: true

                    Image {
                        anchors.fill: parent
                        // Cache off: each capture is a new file at a path that is
                        // never reused, and a cached miss would show the last one.
                        cache: false
                        source: Screenshot.pending.length > 0 ? `file://${Screenshot.pending}` : ""
                        sourceSize.width: 192
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }
                }

                // Everything past the picture arrives once the bar has opened.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space(1)
                    opacity: win.inside

                    // Icons only: the bar is small, and an arrow into a line or a
                    // pencil says it faster than a word would.
                    Repeater {
                        model: ["save", "pencil"]

                        Rectangle {
                            id: act

                            required property string modelData

                            anchors.verticalCenter: parent.verticalCenter
                            width: 34
                            height: 34
                            radius: 17
                            color: actHover.hovered ? Theme.fg : Theme.surfaceHi

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.micro
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.smooth
                                }
                            }

                            Glyph {
                                anchors.centerIn: parent
                                name: act.modelData
                                size: 16
                                color: actHover.hovered ? Theme.bg : Theme.fg
                            }

                            HoverHandler {
                                id: actHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: {
                                    if (act.modelData === "save")
                                        Screenshot.keepPending();
                                    else
                                        Screenshot.editPending();
                                }
                            }
                        }
                    }

                    // Away, and the file with it.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        radius: 14
                        color: dropHover.hovered ? Theme.surfaceTop : "transparent"

                        Glyph {
                            anchors.centerIn: parent
                            name: "close"
                            size: 13
                            color: dropHover.hovered ? Theme.fg : Theme.fgDim
                        }

                        HoverHandler {
                            id: dropHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: Screenshot.dropPending()
                        }
                    }
                }
            }

            // How long is left before it is thrown away. Measured against the
            // flat run of the bar's bottom edge, between the rounded corners and
            // inside the border: clipping is to the square bounds, so a line the
            // full width ran out past the curve at both ends.
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: bar.border.width
                x: bar.radius
                height: 2
                radius: 1
                color: Theme.accent
                width: (bar.width - bar.radius * 2) * Math.max(0, Math.min(1, Screenshot.remaining))
                opacity: win.inside

                // The clock ticks in steps; this smooths them into a slide.
                Behavior on width {
                    NumberAnimation {
                        duration: 60
                    }
                }
            }
        }
    }
}
