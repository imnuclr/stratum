import QtQuick
import qs.components
import qs.services
import qs.theme

Item {
    id: root

    // Centred as a group: three rings left-aligned against a wide column leave
    // an empty third that reads as a missing fourth.
    Row {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.space(4)

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

                spacing: Theme.space(2)

                DotRing {
                    width: 92
                    height: 92
                    count: 44
                    dotSize: 4.2

                    value: modelData.value

                    DotText {
                        anchors.centerIn: parent
                        text: modelData.reading
                        size: 23
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
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.space(4)

        Column {
            width: 180
            spacing: Theme.space(2)

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
                        font.letterSpacing: 0.8
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
                        count: 6
                        dotSize: 2.6
                        litScale: 1.5
                        value: modelData.usage
                    }
                }
            }
        }

        Column {
            spacing: Theme.space(2)

            SectionLabel {
                text: SysStats.frequencyLabel.length > 0 ? `cores · ${SysStats.frequencyLabel}` : "cores"
            }

            // One column per core, all sixteen in a single block — splitting them
            // into two rows of eight implies a grouping the cores do not have.
            DotField {
                rows: 7
                cell: 9.4
                dotSize: 4.4
                values: SysStats.cores
            }
        }
    }
}
