import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme
import qs.modules.dashboard.columns

/*
 * The wide strip: categories divided by vertical hairlines, no scrolling.
 *
 * Each column is its own file, loaded by the name it appears under in
 * dashboard.columns, so reordering or dropping one is a config change.
 */
Sheet {
    id: root

    readonly property var columnNames: Config.get("dashboard.columns", ["time", "weather", "system", "network", "media"])

    name: "dashboard"
    originX: 0.5
    sheetWidth: Math.min(Config.get("dashboard.width", 1900), monitor.width - Theme.space(4) * 2)
    sheetHeight: 220

    /*
     * The polled services idle at a slow tick and speed up while something is
     * reading them. Counting watchers rather than starting and stopping outright
     * means two panels showing the same number don't fight over the timer.
     */
    onOpenChanged: {
        if (open) {
            SysStats.watch();
            Netstat.watch();
            Media.watch();
        } else {
            SysStats.unwatch();
            Netstat.unwatch();
            Media.unwatch();
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 1

        Repeater {
            model: root.columnNames

            Item {
                id: column

                required property int index
                required property string modelData

                readonly property bool last: index === root.columnNames.length - 1

                width: (root.sheetWidth - 2) / root.columnNames.length
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
                        // A name with no column file renders nothing rather than
                        // failing the whole sheet.
                        source: {
                            switch (column.modelData) {
                            case "time":
                                return "columns/TimeColumn.qml";
                            case "weather":
                                return "columns/WeatherColumn.qml";
                            case "system":
                                return "columns/SystemColumn.qml";
                            case "network":
                                return "columns/NetworkColumn.qml";
                            case "media":
                                return "columns/MediaColumn.qml";
                            default:
                                return "";
                            }
                        }
                    }
                }
            }
        }
    }
}
