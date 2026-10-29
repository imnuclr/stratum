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
 * dashboard.columns, so reordering or dropping one is a config change. Columns
 * own their own heading rather than taking the category name, because what
 * belongs at the top differs per column — the interface name for the network,
 * the player for media, the day of the week for time.
 */
Sheet {
    id: root

    readonly property var columnNames: Config.get("dashboard.columns", ["time", "weather", "system", "network", "media"])
    readonly property var weights: Config.get("dashboard.weights", ({}))
    readonly property real weightTotal: {
        let sum = 0;
        for (const n of columnNames)
            sum += weights[n] ?? 1;
        return sum > 0 ? sum : 1;
    }

    name: "dashboard"
    hoverDismiss: true
    originX: 0.5
    sheetWidth: Math.min(Config.get("dashboard.width", 1900), monitor.width - Theme.space(4) * 2)
    sheetHeight: Config.get("dashboard.height", 360)

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
            Gpu.watch();
            Processes.watch();
        } else {
            SysStats.unwatch();
            Netstat.unwatch();
            Media.unwatch();
            Gpu.unwatch();
            Processes.unwatch();
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

                // Proportional, not equal: the system column carries three rings
                // and two sub-tables, the network column two rows.
                width: (root.sheetWidth - 2) * (root.weights[modelData] ?? 1) / root.weightTotal
                height: parent.height

                DotDivider {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - Theme.space(3) * 2
                    visible: !column.last
                }

                Loader {
                    anchors.fill: parent
                    anchors.margins: Theme.space(4)

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
