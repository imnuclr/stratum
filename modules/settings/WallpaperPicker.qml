pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Choosing a wallpaper on the wallpaper: a row of them across the screen, the
 * arrow keys to walk along it, and the desktop behind showing each one as it is
 * reached. Enter keeps the one you are on, Escape puts back what was there.
 *
 * The same controls as the small panel sit attached at the top, so how it is drawn
 * can be changed while looking at the result. Opened by holding on the wallpaper,
 * or `qs -c stratum ipc call panel open picker`.
 *
 * Like the other panels the window stays mapped whether or not it is showing, so
 * it appears by fading in rather than by the compositor playing its own open
 * animation on a new surface.
 */
PanelWindow {
    id: root

    required property ShellScreen monitor

    readonly property bool open: Shell.openPanel === "picker"
        && (Shell.openScreen.length === 0 ? monitor.name === Shell.fallbackScreen : Shell.openScreen === monitor.name)

    readonly property var entries: Wallpaper.entries
    // What was on the desktop when the picker opened, for Escape to put back.
    property string original: ""
    property int index: 0

    // Fades up and down with `open`.
    property real shown: root.open ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.sheetMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft
        }
    }

    function baseName(path) {
        return path ? path.slice(path.lastIndexOf("/") + 1) : "";
    }

    function go(to) {
        if (root.entries.length === 0)
            return;
        root.index = Math.max(0, Math.min(root.entries.length - 1, to));
        preview.restart();
    }

    function keep() {
        preview.stop();
        Wallpaper.set(root.entries[root.index]);
        Shell.close();
    }

    function revert() {
        preview.stop();
        if (root.original.length > 0)
            Wallpaper.set(root.original);
        Shell.close();
    }

    onOpenChanged: {
        if (!open)
            return;
        root.original = Wallpaper.current;
        const at = root.entries.indexOf(Wallpaper.forMonitor(monitor.name));
        root.index = Math.max(0, at);
        keys.forceActiveFocus();
    }

    // Walking along quickly should not ask for a new picture on every key press.
    Timer {
        id: preview

        interval: 90
        onTriggered: Wallpaper.set(root.entries[root.index])
    }

    screen: monitor
    visible: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "stratum-picker"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        x: 0
        y: 0
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true
        opacity: root.shown

        Keys.onEscapePressed: root.revert()
        Keys.onReturnPressed: root.keep()
        Keys.onEnterPressed: root.keep()
        Keys.onSpacePressed: root.keep()
        Keys.onLeftPressed: root.go(root.index - 1)
        Keys.onRightPressed: root.go(root.index + 1)
        Keys.onUpPressed: root.go(root.index - 5)
        Keys.onDownPressed: root.go(root.index + 5)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Home)
                root.go(0);
            else if (event.key === Qt.Key_End)
                root.go(root.entries.length - 1);
            else if (event.key === Qt.Key_Tab)
                Wallpaper.random("");
            else
                return;
            event.accepted = true;
        }

        // A click on bare screen keeps the one being shown and closes.
        MouseArea {
            anchors.fill: parent
            onClicked: root.keep()
            onWheel: wheel => root.go(root.index + (wheel.angleDelta.y > 0 ? -1 : 1))
        }

        // Where in the folder, and which one.
        Column {
            x: Theme.space(7) * 2.4
            y: Theme.space(6)
            spacing: Theme.space(2)
            transform: Translate {
                y: (1 - root.shown) * -16
            }

            SectionLabel {
                text: `wallpaper · ${root.entries.length} in ${Wallpaper.dir.replace(Quickshell.env("HOME"), "~")}`
                color: Theme.fgBright
            }

            Row {
                spacing: Theme.space(3)

                DotText {
                    text: String(root.index + 1).padStart(2, "0")
                    size: 76
                }

                SectionLabel {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.space(3)
                    text: `/ ${root.entries.length}`
                    color: Theme.fgBright
                }
            }

            SectionLabel {
                text: root.baseName(root.entries[root.index] ?? "")
                color: Theme.fg
            }
        }

        // How it is drawn, attached at the top right.
        Rectangle {
            id: panel

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Theme.space(6)
            anchors.rightMargin: Theme.space(6)
            width: controls.implicitWidth + Theme.space(5) * 2
            height: controls.implicitHeight + Theme.space(5) * 2
            radius: Theme.rSheet
            color: Theme.deep
            border.width: 1
            border.color: Theme.outline
            transform: Translate {
                y: (1 - root.shown) * -16
            }

            // Swallows clicks and scrolls so they do not reach the screen behind.
            MouseArea {
                anchors.fill: parent
                onWheel: wheel => wheel.accepted = true
            }

            WallpaperControls {
                id: controls

                anchors.centerIn: parent
            }
        }

        // The row of wallpapers.
        ListView {
            id: strip

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space(7) * 2.6
            height: 200
            orientation: ListView.Horizontal
            spacing: Theme.space(3)
            model: root.entries
            clip: false
            interactive: false
            currentIndex: root.index
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: width / 2 - 55
            preferredHighlightEnd: width / 2 + 55
            highlightMoveDuration: Theme.standard * 2
            highlightMoveVelocity: -1
            cacheBuffer: 1200
            transform: Translate {
                y: (1 - root.shown) * 24
            }

            delegate: Item {
                id: cell

                required property string modelData
                required property int index

                readonly property int distance: Math.abs(cell.index - root.index)
                readonly property bool current: cell.distance === 0

                width: 110
                height: strip.height

                ClippingRectangle {
                    id: disc

                    anchors.centerIn: parent
                    width: 110
                    height: 110
                    radius: width / 2
                    color: Theme.surfaceHi
                    scale: cell.current ? 1.5 : Math.max(0.45, 0.95 - cell.distance * 0.1)
                    opacity: cell.current ? 1 : Math.max(0.25, 0.85 - cell.distance * 0.14)

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.standard * 1.6
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.soft
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.standard
                        }
                    }

                    Image {
                        anchors.fill: parent
                        source: `file://${cell.modelData}`
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 240
                        sourceSize.height: 240
                        asynchronous: true
                        cache: true
                    }
                }

                // The chosen one sits in a ring.
                Rectangle {
                    anchors.centerIn: parent
                    width: 110 * 1.5 + 14
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1.5
                    border.color: Theme.outline
                    opacity: cell.current ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.standard
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: cell.current ? root.keep() : root.go(cell.index)
                }
            }
        }

        // What the keys do.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space(5)
            spacing: Theme.space(5)

            Repeater {
                model: ["← → browse", "↑ ↓ jump", "tab shuffle", "enter set", "esc back"]

                SectionLabel {
                    required property string modelData

                    text: modelData
                    color: Theme.fgBright
                }
            }
        }
    }
}
