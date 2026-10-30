import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Processor, memory and graphics at a glance, with a minute of processor load.
 */
Item {
    id: root

    Component.onCompleted: {
        SysStats.watch();
        Gpu.watch();
    }
    Component.onDestruction: {
        SysStats.unwatch();
        Gpu.unwatch();
    }

    readonly property var figures: [
        { label: "cpu", value: `${Math.round(SysStats.cpu * 100)}%` },
        { label: "mem", value: SysStats.memoryShort },
        { label: "gpu", value: Gpu.available ? `${Math.round(Gpu.usage * 100)}%` : "--" },
        { label: "temp", value: SysStats.temperature > 0 ? `${Math.round(SysStats.temperature)}°` : "--" }
    ]

    Grid {
        anchors.left: parent.left
        anchors.leftMargin: Theme.space(5)
        anchors.verticalCenter: parent.verticalCenter
        columns: 2
        rowSpacing: Theme.space(4)
        columnSpacing: Theme.space(6)

        Repeater {
            model: root.figures

            Column {
                required property var modelData

                spacing: 2

                SectionLabel {
                    text: parent.modelData.label
                    color: Theme.fgBright
                }

                DotText {
                    text: parent.modelData.value
                    size: 24
                    plain: true
                }
            }
        }
    }

    // A minute of load, one column of dots per sample.
    Column {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space(5)
        anchors.top: parent.top
        anchors.topMargin: Theme.space(4)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space(4)
        width: Math.max(120, root.width * 0.42)
        spacing: Theme.space(2)

        SectionLabel {
            text: "cpu · 60 s"
            color: Theme.fgBright
        }

        Row {
            id: graph

            readonly property int rows: 6
            readonly property real pitch: width / SysStats.historyLength

            width: parent.width
            height: parent.height - Theme.space(2) - 12
            spacing: 0

            Repeater {
                model: SysStats.cpuHistory

                Column {
                    required property real modelData

                    width: graph.pitch
                    height: graph.height
                    spacing: (graph.height - graph.rows * 3) / (graph.rows - 1)

                    Repeater {
                        model: graph.rows

                        Rectangle {
                            required property int index

                            width: 3
                            height: 3
                            radius: 1.5
                            anchors.horizontalCenter: parent.horizontalCenter
                            // Lit from the bottom up.
                            color: (graph.rows - 1 - index) < Math.max(1, Math.round(parent.modelData * graph.rows))
                                ? Theme.dotOn : Theme.dotOff
                        }
                    }
                }
            }
        }
    }
}
