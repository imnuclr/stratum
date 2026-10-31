pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * What to do with the screenshot just taken: a bar at the foot of the screen
 * with the picture itself, and save or edit.
 *
 * Nothing has been saved at this point — the capture is on the clipboard and in
 * a temporary file — so leaving it alone throws it away, and the line along the
 * bottom shows how long that is. Pointing at it stops the clock.
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
        implicitHeight: 150

        // Only the bar takes input; the rest of the strip is not there.
        mask: Region {
            item: bar.opacity > 0.01 ? bar : null
        }

        Rectangle {
            id: bar

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space(7)
            width: row.implicitWidth + Theme.space(4) * 2
            height: 76
            radius: Theme.rTile
            color: Theme.deep
            border.width: 1
            border.color: Theme.outline
            opacity: win.up ? 1 : 0
            visible: opacity > 0.01
            // Rises as it arrives, so it reads as coming up from the edge.
            y: parent.height - height - Theme.space(7) + (win.up ? 0 : 16)
            clip: true

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.standard * 1.6
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: Theme.standard * 1.6
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

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
                anchors.leftMargin: Theme.space(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space(3)

                // The capture itself, so there is no doubt what is being kept.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 84
                    height: 52
                    radius: Theme.rInner - 4
                    color: Theme.surfaceHi
                    clip: true

                    Image {
                        anchors.fill: parent
                        // Cache off: each capture is a new file at a path that is
                        // never reused, and a cached miss would show the last one.
                        cache: false
                        source: Screenshot.pending.length > 0 ? `file://${Screenshot.pending}` : ""
                        sourceSize.width: 256
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Text {
                        text: "Screenshot copied"
                        color: Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    SectionLabel {
                        text: "not saved yet"
                        color: Theme.fgDim
                    }
                }

                Item {
                    width: Theme.space(2)
                    height: 1
                }

                LinkButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "check"
                    text: "save"
                    onClicked: Screenshot.keepPending()
                }

                LinkButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "app"
                    text: "edit"
                    onClicked: Screenshot.editPending()
                }

                // Away, and the file with it.
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    height: 32
                    radius: 16
                    color: dropHover.hovered ? Theme.surfaceTop : "transparent"

                    Glyph {
                        anchors.centerIn: parent
                        name: "close"
                        size: 14
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

            // How long is left before it is thrown away.
            Rectangle {
                id: clock

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                height: 2
                color: Theme.accent
                width: 0

                NumberAnimation {
                    id: counting

                    target: clock
                    property: "width"
                    from: bar.width
                    to: 0
                    duration: Config.get("screenshot.offerMs", 9000)
                }

                // Restarted for each new capture; paused while pointed at.
                Connections {
                    target: Screenshot

                    function onPendingChanged() {
                        if (Screenshot.offering)
                            counting.restart();
                        else
                            counting.stop();
                    }

                    function onHeldChanged() {
                        if (!Screenshot.offering)
                            return;
                        if (Screenshot.held)
                            counting.pause();
                        else
                            counting.resume();
                    }
                }
            }
        }
    }
}
