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

        WallpaperControls {
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
