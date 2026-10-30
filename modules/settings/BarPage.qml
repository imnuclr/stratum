import QtQuick
import qs.components
import qs.config
import qs.theme

/*
 * The bar: whether it is there, which edge it sits on, how big it is.
 * Changes apply as they are made.
 */
Flickable {
    id: page

    readonly property bool vertical: Config.get("bar.orientation", "vertical") === "vertical"

    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: body

        width: page.width
        spacing: 0

        SectionLabel {
            text: "bar"
            bottomPadding: Theme.space(3)
        }

        SettingRow {
            width: parent.width
            title: "Show the bar"
            detail: "Off hides it on every display. Each display can also be set on its own, under Monitors."

            Switch {
                checked: Config.get("bar.enabled", true)
                onToggled: value => Config.set("bar.enabled", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Shape"
            detail: "A column down one side, or a strip along the top or bottom."

            Segmented {
                model: ["column", "strip"]
                current: page.vertical ? 0 : 1
                onPicked: index => {
                    Config.set("bar.orientation", index === 0 ? "vertical" : "horizontal");
                    Config.set("bar.edge", index === 0 ? "left" : "top");
                }
            }
        }

        SettingRow {
            width: parent.width
            title: "Edge"

            Segmented {
                readonly property var edges: page.vertical ? ["left", "right"] : ["top", "bottom"]

                model: edges
                current: Math.max(0, edges.indexOf(Config.get("bar.edge", page.vertical ? "left" : "top")))
                onPicked: index => Config.set("bar.edge", edges[index])
            }
        }

        SettingRow {
            width: parent.width
            title: page.vertical ? "Width" : "Height"
            detail: "How thick the bar is, in pixels."

            Stepper {
                readonly property string key: page.vertical ? "bar.width" : "bar.height"

                value: Config.get(key, page.vertical ? 56 : 38)
                from: page.vertical ? 40 : 28
                to: page.vertical ? 96 : 64
                step: 2
                suffix: " px"
                onMoved: v => Config.set(key, v)
            }
        }

        SettingRow {
            width: parent.width
            title: "Margin"
            detail: "Space between the bar and the edge of the screen."

            Stepper {
                value: Config.get("bar.margin", 10)
                from: 0
                to: 32
                step: 2
                suffix: " px"
                onMoved: v => Config.set("bar.margin", v)
            }
        }

        SettingRow {
            width: parent.width
            visible: !page.vertical
            title: "Layout"
            detail: "Edges puts the islands at the corners; thirds at a quarter, half and three quarters across, which keeps them closer together on a wide display."

            Segmented {
                model: ["edges", "thirds"]
                current: Config.get("bar.layout", "edges") === "thirds" ? 1 : 0
                onPicked: index => Config.set("bar.layout", index === 1 ? "thirds" : "edges")
            }
        }

        SettingRow {
            width: parent.width
            title: "Workspaces"
            detail: "How many workspace dots the bar shows."

            Stepper {
                value: Config.get("bar.workspaces.count", 6)
                from: 1
                to: 10
                step: 1
                onMoved: v => Config.set("bar.workspaces.count", v)
            }
        }
    }
}
