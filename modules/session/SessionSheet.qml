import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Lock, leave, sleep, restart, shut down.
 *
 * Nothing here is confirmed twice. Each action is one deliberate click on a
 * named control, and a second dialog asking "are you sure" is the kind of thing
 * people learn to click through without reading. The two that lose work are
 * marked by turning red under the pointer instead.
 */
Sheet {
    id: root

    name: "session"
    // Beside whatever opened it: the bar's edge when asked for from the bar, the
    // control centre's corner otherwise.
    originX: Shell.openFrom === "bar" ? (barRight ? 1 : 0) : 1
    originY: 1
    clickDismiss: true
    // Once the pointer has been on it, leaving it closes it.
    hoverDismiss: true
    adoptOnOpen: false
    sheetWidth: Config.get("session.width", 300)
    sheetHeight: body.implicitHeight + Theme.space(4) * 2

    Column {
        id: body

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.space(4)
        spacing: Theme.space(2)

        SectionLabel {
            text: "session"
        }

        Repeater {
            model: [
                { icon: "lock", label: "lock", cmd: ["loginctl", "lock-session"], danger: false },
                { icon: "link-off", label: "log out", cmd: ["hyprctl", "dispatch", "exit"], danger: false },
                { icon: "moon", label: "sleep", cmd: ["systemctl", "suspend"], danger: false },
                { icon: "scan", label: "restart", cmd: ["systemctl", "reboot"], danger: true },
                { icon: "power", label: "shut down", cmd: ["systemctl", "poweroff"], danger: true }
            ]

            Rectangle {
                id: entry

                required property var modelData

                width: parent.width
                height: 48
                radius: height / 2
                color: hover.hovered
                    ? (entry.modelData.danger ? Theme.accent : Theme.surfaceTop)
                    : Theme.surfaceHi

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space(4)
                    spacing: Theme.space(3)

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: entry.modelData.icon
                        size: 18
                        color: hover.hovered && entry.modelData.danger ? Theme.bg : Theme.fgBright
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.label
                        color: hover.hovered && entry.modelData.danger ? Theme.bg : Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: 15
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        Shell.close();
                        action.command = entry.modelData.cmd;
                        action.running = true;
                    }
                }
            }
        }
    }

    Process {
        id: action
    }
}
