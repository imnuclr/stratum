import QtQuick
import qs.components
import qs.services
import qs.theme

Column {
    id: root

    spacing: Theme.space(3)

    Row {
        spacing: Theme.space(3)

        Repeater {
            // Captions carry a second reading each, so the rings can stay as
            // bare numbers without losing what they refer to.
            model: [
                { value: SysStats.cpu, reading: `${Math.round(SysStats.cpu * 100)}`, caption: `cpu · ${Math.round(SysStats.temperature)}°` },
                { value: SysStats.memory, reading: `${Math.round(SysStats.memory * 100)}`, caption: `mem · ${SysStats.memoryShort}` },
                { value: Gpu.usage, reading: Gpu.available ? `${Math.round(Gpu.usage * 100)}` : "--", caption: Gpu.available ? `gpu · ${Math.round(Gpu.temperature)}°` : "gpu · n/a" }
            ]

            Column {
                required property var modelData

                spacing: Theme.space(1)

                DotRing {
                    width: 74
                    height: 74
                    count: 40
                    dotSize: 3.2
                    value: modelData.value

                    DotText {
                        anchors.centerIn: parent
                        text: modelData.reading
                        size: 17
                    }
                }

                SectionLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    dim: true
                    text: modelData.caption
                }
            }
        }
    }

    Row {
        spacing: Theme.space(4)

        Column {
            spacing: Theme.space(1)

            SectionLabel {
                text: "processes"
            }

            Repeater {
                model: Processes.top

                Row {
                    required property var modelData

                    spacing: Theme.space(2)

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 92
                        elide: Text.ElideRight
                        text: modelData.name.toUpperCase()
                        color: Theme.fgDim
                        font.family: Theme.fontUi
                        font.pixelSize: 11
                        font.letterSpacing: 0.6
                        renderType: Text.NativeRendering
                    }

                    // DotText is a Row, so it has no width of its own to align
                    // within; the fixed box is what keeps the percentages in a
                    // column instead of drifting with name length.
                    Item {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        height: pct.implicitHeight

                        DotText {
                            id: pct

                            anchors.right: parent.right
                            text: `${Math.round(modelData.usage * 100)}%`
                            size: 13
                        }
                    }

                    DotBar {
                        anchors.verticalCenter: parent.verticalCenter
                        count: 5
                        dotSize: 2.8
                        value: modelData.usage
                    }
                }
            }
        }

        Column {
            spacing: Theme.space(1)

            SectionLabel {
                text: SysStats.frequencyLabel.length > 0 ? `cores · ${SysStats.frequencyLabel}` : "cores"
            }

            // Sixteen cores in one row would be wider than the column, so they
            // wrap into two.
            Column {
                spacing: 2

                Repeater {
                    model: 2

                    DotField {
                        required property int index

                        rows: 5
                        cell: 6.4
                        dotSize: 3.6
                        values: SysStats.cores.slice(index * 8, index * 8 + 8)
                    }
                }
            }
        }
    }
}
