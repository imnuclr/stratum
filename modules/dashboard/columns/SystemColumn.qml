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

        // Built once and left in place: the readings are bindings on each ring,
        // so a new value moves the ring rather than replacing it. They used to be
        // an array of readings handed to a Repeater, which rebuilt all three rings
        // on every poll and so could never animate.
        MetricRing {
            size: 92
            numberSize: 23
            value: SysStats.cpu
            number: SysStats.cpu * 100
            caption: SysStats.temperature > 0 ? `cpu · ${Math.round(SysStats.temperature)}°` : "cpu"
        }

        MetricRing {
            size: 92
            numberSize: 23
            value: SysStats.memory
            number: SysStats.memory * 100
            caption: `mem · ${SysStats.memoryShort}`
        }

        MetricRing {
            size: 92
            numberSize: 23
            value: Gpu.usage
            number: Gpu.available ? Gpu.usage * 100 : -1
            caption: Gpu.available ? (Gpu.temperature > 0 ? `gpu · ${Math.round(Gpu.temperature)}°` : "gpu") : "gpu · n/a"
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
                            plain: true
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
