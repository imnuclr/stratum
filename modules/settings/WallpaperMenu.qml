import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * How the wallpaper is drawn, in a small panel of its own at the foot of the
 * screen — so the picture stays in view while it is being changed, which the
 * settings page covering the middle of it does not allow.
 *
 * Open with `qs -c stratum ipc call panel open wallpaper`, or from the edit button
 * on the wallpaper page.
 */
Sheet {
    id: root

    name: "wallpaper"
    deep: true
    clickDismiss: true
    originX: 0.5
    originY: 1
    sheetWidth: 520
    sheetHeight: body.implicitHeight + Theme.space(4) * 2

    Column {
        id: body

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.space(4)
        spacing: Theme.space(4)

        Item {
            width: parent.width
            height: 32

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: "wallpaper"
                color: Theme.fgBright
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                spacing: Theme.space(1)

                IconButton {
                    icon: "skip-back"
                    size: 32
                    onClicked: Wallpaper.cycle(-1, "")
                }

                ActionButton {
                    text: "shuffle"
                    width: 84
                    height: 32
                    onClicked: Wallpaper.random("")
                }

                IconButton {
                    icon: "skip-forward"
                    size: 32
                    onClicked: Wallpaper.cycle(1, "")
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.space(3)

            Segmented {
                model: ["original", "dots"]
                current: Config.get("wallpaper.look", "original") === "dots" ? 1 : 0
                onPicked: index => Config.set("wallpaper.look", index === 1 ? "dots" : "original")
            }

            Segmented {
                model: ["colour", "mono"]
                current: Config.get("wallpaper.mono", false) ? 1 : 0
                onPicked: index => Config.set("wallpaper.mono", index === 1)
            }
        }

        // What the rings change only exists in the dotted look.
        Row {
            id: rings

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Theme.space(6)
            opacity: Config.get("wallpaper.look", "original") === "dots" ? 1 : 0.35
            enabled: Config.get("wallpaper.look", "original") === "dots"

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.standard
                }
            }

            RingDial {
                id: sizeRing

                // Size of each dot, as a share of the space it has.
                value: (Config.get("wallpaper.dotScale", 0.5) - 0.2) / 0.75
                reading: `${Math.round((0.2 + sizeRing.live * 0.75) * 100)}`
                caption: "dot · size"
                onCommitted: v => Config.set("wallpaper.dotScale", Math.round((0.2 + v * 0.75) * 100) / 100)
            }

            RingDial {
                id: amountRing

                // How many dots across: more of them means a finer grid.
                value: Config.get("wallpaper.dotAmount", 0.8)
                reading: `${Math.round(amountRing.live * 100)}`
                caption: "dots · amount"
                onCommitted: v => Config.set("wallpaper.dotAmount", Math.round(v * 100) / 100)
            }

            RingDial {
                id: lightRing

                // How bright the dots are, not how big: that is the first ring.
                value: (Math.min(1, Config.get("wallpaper.light", 1)) - 0.15) / 0.85
                reading: `${Math.round((0.15 + lightRing.live * 0.85) * 100)}`
                caption: "light · %"
                onCommitted: v => Config.set("wallpaper.light", Math.round((0.15 + v * 0.85) * 20) / 20)
            }
        }

        SectionLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            dim: true
            text: Config.get("wallpaper.look", "original") === "dots"
                ? "drag a ring up or down, or scroll over it"
                : "switch to dots to shape them"
        }
    }
}
