import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The desktop widgets: whether they are shown, whether they step aside for
 * windows, and the way into arranging them.
 */
Flickable {
    id: page

    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: body

        width: page.width
        spacing: 0

        SectionLabel {
            text: "widgets"
            bottomPadding: Theme.space(3)
        }

        SettingRow {
            width: parent.width
            title: "Show widgets"
            detail: "The clock, weather, now playing and the rest, on the bare desktop."

            Switch {
                checked: Config.get("widgets.enabled", true)
                onToggled: value => Config.set("widgets.enabled", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Hide behind windows"
            detail: "Fade the widgets away while any window is open on the workspace, and bring them back when it is clear."

            Switch {
                checked: Config.get("widgets.hideCovered", true)
                onToggled: value => Config.set("widgets.hideCovered", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Arrange"
            detail: "Move, resize, add and remove widgets. Also: hold on a widget, right-click the desktop, or Super + Shift + W."

            ActionButton {
                text: "arrange"
                width: 110
                onClicked: {
                    Shell.close();
                    Widgets.editing = true;
                }
            }
        }

        SettingRow {
            width: parent.width
            title: "Reset every display"
            detail: "Puts back the default arrangement everywhere."

            ActionButton {
                text: "reset"
                width: 96
                onClicked: {
                    for (const screen of Quickshell.screens)
                        Widgets.reset(screen.name);
                }
            }
        }
    }
}
