import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * What the shell is doing and where it keeps things, for when something is wrong.
 */
Item {
    id: page

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SectionLabel {
            text: "advanced"
            bottomPadding: Theme.space(3)
        }

        SettingRow {
            width: parent.width
            title: "Diagnostic tracing"
            detail: "Logs hover, panel and popout events. Read it with `stratum trace`. Noisy, so off unless something is misbehaving."

            Switch {
                checked: Config.get("debug.trace", false)
                onToggled: value => Config.set("debug.trace", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Settings folder"
            detail: Theme.dir

            ActionButton {
                text: "open"
                width: 84
                onClicked: Quickshell.execDetached(["xdg-open", Theme.dir])
            }
        }

        SettingRow {
            width: parent.width
            title: "Wallpaper folder"
            detail: Wallpaper.dir

            ActionButton {
                text: "rescan"
                width: 84
                onClicked: Wallpaper.scan()
            }
        }
    }
}
