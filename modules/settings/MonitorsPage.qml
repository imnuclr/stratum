pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Each display on its own: whether it has a bar and on which edge, its wallpaper,
 * and its widgets. Anything not set here follows the bar page.
 */
Flickable {
    id: page

    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: body

        width: page.width
        spacing: Theme.space(4)

        SectionLabel {
            text: "monitors"
        }

        Repeater {
            model: Quickshell.screens

            Rectangle {
                id: card

                required property ShellScreen modelData

                readonly property string name: card.modelData.name
                readonly property string prefix: `monitors.${card.name}.bar`
                readonly property bool vertical: Config.forMonitor(card.name, "bar.orientation", "vertical") === "vertical"

                width: body.width
                height: rows.implicitHeight + Theme.space(4) * 2
                radius: Theme.rTile
                color: Theme.surfaceHi

                Column {
                    id: rows

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.space(4)
                    spacing: 0

                    Row {
                        spacing: Theme.space(3)
                        bottomPadding: Theme.space(2)

                        Text {
                            text: card.name
                            color: Theme.fg
                            font.family: Theme.fontUi
                            font.pixelSize: 16
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }

                        SectionLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: `${card.modelData.model ?? ""} · ${card.modelData.width} × ${card.modelData.height}`
                            color: Theme.fgDim
                        }
                    }

                    SettingRow {
                        width: parent.width
                        title: "Bar on this display"

                        Switch {
                            checked: Config.forMonitor(card.name, "bar.enabled", true)
                            onToggled: value => Config.set(`${card.prefix}.enabled`, value)
                        }
                    }

                    SettingRow {
                        width: parent.width
                        title: "Edge"
                        detail: "Default follows the bar page."

                        Segmented {
                            readonly property var edges: card.vertical ? ["default", "left", "right"] : ["default", "top", "bottom"]
                            readonly property string set: Config.get(`${card.prefix}.edge`, "")

                            model: edges
                            current: Math.max(0, edges.indexOf(set))
                            onPicked: index => {
                                if (index === 0)
                                    Config.unset(`${card.prefix}.edge`);
                                else
                                    Config.set(`${card.prefix}.edge`, edges[index]);
                            }
                        }
                    }

                    SettingRow {
                        width: parent.width
                        title: "Wallpaper"
                        detail: Wallpaper.forMonitor(card.name).split("/").pop()

                        ActionButton {
                            text: "choose"
                            width: 96
                            onClicked: Shell.open("picker", card.name)
                        }
                    }

                    SettingRow {
                        width: parent.width
                        title: "Widgets"
                        detail: "Each display keeps its own arrangement."

                        ActionButton {
                            text: "reset layout"
                            width: 120
                            onClicked: Widgets.reset(card.name)
                        }
                    }
                }
            }
        }
    }
}
