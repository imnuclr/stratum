import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The wide strip: categories divided by vertical hairlines, no scrolling.
 * Columns are placeholders until phase 3; the time column is already live.
 */
Sheet {
    id: root

    name: "dashboard"
    originX: 0.5
    sheetWidth: Math.min(Config.get("dashboard.width", 1900), monitor.width - Theme.space(4) * 2)
    sheetHeight: 220

    Row {
        anchors.fill: parent
        anchors.margins: 1

        Repeater {
            model: Config.get("dashboard.columns", ["time", "weather", "system", "network", "media"])

            Item {
                id: column

                required property int index
                required property string modelData

                readonly property bool last: index === Config.get("dashboard.columns", []).length - 1

                width: (root.sheetWidth - 2) / Config.get("dashboard.columns", []).length
                height: parent.height

                Rectangle {
                    anchors.right: parent.right
                    width: 1
                    height: parent.height - Theme.space(3) * 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.line
                    visible: !column.last
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.space(3)
                    spacing: Theme.space(2)

                    SectionLabel {
                        text: column.modelData
                    }

                    Loader {
                        active: column.modelData === "time"
                        visible: active

                        sourceComponent: Column {
                            spacing: Theme.space(2)

                            DotText {
                                text: Time.format("HH:mm")
                                size: 52
                            }

                            SectionLabel {
                                dim: true
                                text: `${Time.format("d MMMM")} · week ${Time.weekNumber()}`
                            }

                            DotBar {
                                count: 30
                                value: Time.dayProgress
                            }
                        }
                    }

                    // Phase 3 fills the rest. Until then each column shows the
                    // primitive it will be built from, driven by real values where
                    // one exists, so a regression in a primitive is visible here.
                    Loader {
                        active: column.modelData === "media"
                        visible: active

                        sourceComponent: DotImage {
                            width: 104
                            height: 104
                            cell: 4
                            // Phase 3 replaces this with Mpris track artwork.
                            source: Config.get("dashboard.artPlaceholder", "")
                        }
                    }

                    Loader {
                        active: column.modelData !== "time" && column.modelData !== "media"
                        visible: active

                        sourceComponent: Row {
                            spacing: Theme.space(3)

                            DotRing {
                                width: 74
                                height: 74
                                count: 40
                                dotSize: 3.2
                                value: 0.43

                                DotText {
                                    anchors.centerIn: parent
                                    text: "43"
                                    size: 17
                                }
                            }

                            DotField {
                                anchors.verticalCenter: parent.verticalCenter
                                rows: 6
                                cell: 7
                                dotSize: 4
                                values: [0.2, 0.5, 0.35, 0.8, 0.6, 0.9, 0.45, 0.7, 0.3, 0.55]
                            }
                        }
                    }
                }
            }
        }
    }
}
