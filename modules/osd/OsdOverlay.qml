pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

/*
 * A small pill at the foot of the screen that answers a key press: an icon, a
 * short row of dots for the level, and the number.
 *
 * Quiet on purpose. It is the notification toast's own shape and finish — black,
 * pale outline, grows out of a pill and fades its words in — kept small and put
 * where a glance reaches without anything having to move. It is on the overlay
 * layer, so it shows over a fullscreen window as well, and it takes no input.
 *
 * Only on the display being worked on, like toasts.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        readonly property bool focused: Hypr.focusedWorkspace?.monitor?.name === win.modelData.name
        readonly property bool up: Osd.shown && win.focused

        // 0 is the bare pill, 1 the whole indicator.
        property real p: 0

        screen: modelData
        visible: true
        color: "transparent"
        mask: Region {}
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "stratum-osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        implicitHeight: 120

        onUpChanged: {
            grow.to = win.up ? 1 : 0;
            grow.duration = win.up ? 150 : 110;
            grow.restart();
        }

        NumberAnimation {
            id: grow

            target: win
            property: "p"
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft
        }

        Rectangle {
            id: pill

            readonly property real fullWidth: row.implicitWidth + Theme.space(5) * 2

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space(7)
            width: 44 + (fullWidth - 44) * win.p
            height: 44
            radius: height / 2
            color: Theme.deep
            border.width: 1
            border.color: Theme.outline
            opacity: Math.min(1, win.p * 6)
            visible: win.p > 0.001
            clip: true

            Row {
                id: row

                anchors.centerIn: parent
                spacing: Theme.space(3)
                opacity: Math.max(0, Math.min(1, (win.p - 0.45) / 0.4))

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Osd.icon
                    size: 18
                    color: Osd.dim ? Theme.fgDim : Theme.fg
                }

                // A level when there is one. The level glides to each new value and the
                // dot at its edge fills in by degrees, so a step of a couple of percent
                // is something to see rather than a number changing.
                Row {
                    id: level

                    property real shown: Osd.level >= 0 ? Osd.level : 0
                    readonly property int count: 14

                    anchors.verticalCenter: parent.verticalCenter
                    visible: Osd.level >= 0
                    spacing: 6

                    Behavior on shown {
                        NumberAnimation {
                            duration: 110
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.soft
                        }
                    }

                    Repeater {
                        model: level.count

                        Rectangle {
                            required property int index

                            readonly property real amount: Math.max(0, Math.min(1, level.shown * level.count - index))

                            width: 3.4
                            height: 3.4
                            radius: 1.7
                            anchors.verticalCenter: parent.verticalCenter
                            color: Qt.tint(Theme.dotOff, Qt.alpha(Osd.dim ? Theme.fgDim : Theme.dotOn, amount))
                            scale: 1 + amount * 0.25
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Osd.label
                    color: Osd.dim ? Theme.fgDim : Theme.fg
                    font.family: Theme.fontDot
                    font.pixelSize: 17
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
