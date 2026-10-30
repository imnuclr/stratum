import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Processor, memory, graphics and disk in large numerals, with a minute of
 * processor load as a field of dots beside them.
 */
Item {
    id: root

    Component.onCompleted: {
        SysStats.watch();
        Gpu.watch();
        Disk.watch();
    }
    Component.onDestruction: {
        SysStats.unwatch();
        Gpu.unwatch();
        Disk.unwatch();
    }

    readonly property real figure: Math.max(22, root.height * 0.22)

    readonly property var figures: [
        { label: "cpu", value: `${Math.round(SysStats.cpu * 100)}%` },
        { label: "mem", value: SysStats.memoryShort },
        { label: "gpu", value: Gpu.available ? (Gpu.temperature > 0 ? `${Math.round(Gpu.temperature)}°` : `${Math.round(Gpu.usage * 100)}%`) : "--" },
        { label: "disk", value: Disk.available ? `${Math.round(Disk.used * 100)}%` : "--" }
    ]

    Grid {
        anchors.left: parent.left
        anchors.leftMargin: Theme.space(5)
        anchors.verticalCenter: parent.verticalCenter
        columns: 2
        rowSpacing: Math.round(root.height * 0.1)
        columnSpacing: Math.round(root.width * 0.08)

        Repeater {
            model: root.figures

            Column {
                required property var modelData

                spacing: Theme.space(1)

                SectionLabel {
                    text: parent.modelData.label
                    color: Theme.fgDim
                }

                DotText {
                    text: parent.modelData.value
                    size: root.figure
                    plain: true
                }
            }
        }
    }

    // A minute of load, one column per sample, on a field of unlit dots.
    Column {
        anchors.right: parent.right
        anchors.rightMargin: Theme.space(5)
        anchors.top: parent.top
        anchors.topMargin: Theme.space(5)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space(5)
        width: Math.max(120, root.width * 0.4)
        spacing: Theme.space(3)

        SectionLabel {
            text: "cpu · 60 s"
            color: Theme.fgDim
        }

        Row {
            id: graph

            readonly property int rows: 7
            readonly property real pitch: width / SysStats.historyLength

            width: parent.width
            height: parent.height - Theme.space(3) - 14

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
                            // Lit from the bottom up; the floor row is always lit, so
                            // an idle machine still draws its line.
                            color: (graph.rows - 1 - index) < Math.max(1, Math.round(parent.modelData * graph.rows))
                                ? Theme.dotOn : Theme.dotOff
                        }
                    }
                }
            }
        }
    }
}
