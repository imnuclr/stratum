pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * CPU, memory and temperature, read straight from /proc and /sys.
 *
 * FileView does work on procfs, but these files report size 0 and change under
 * you, so each one is re-read on a tick rather than watched — watchChanges never
 * fires for them.
 *
 * CPU percentage has to be derived from the difference between two samples of
 * /proc/stat: the file holds cumulative jiffies since boot, so a single read
 * gives the average since startup, not the load right now.
 */
Singleton {
    id: root

    property real cpu: 0
    property real memory: 0
    property real swap: 0
    property real temperature: 0

    property int memTotalKb: 0
    property int memUsedKb: 0

    readonly property string memoryLabel: `${(memUsedKb / 1048576).toFixed(1)} / ${(memTotalKb / 1048576).toFixed(1)} GiB`

    // Rolling CPU history for the dashboard's dot field, oldest first.
    property var cpuHistory: []
    readonly property int historyLength: 10

    property int lastIdle: 0
    property int lastTotal: 0

    // Consumers that want a faster tick while something is on screen.
    property int watchers: 0

    function watch() {
        root.watchers++;
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
    }

    function refresh() {
        statFile.reload();
        memFile.reload();
        tempFile.reload();
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.watchers > 0 ? 1000 : 5000
        onTriggered: root.refresh()
    }

    FileView {
        id: statFile

        path: "/proc/stat"

        onLoaded: {
            const line = text().split("\n")[0];
            if (!line.startsWith("cpu "))
                return;

            const parts = line.split(/\s+/).slice(1).map(Number);
            const idle = parts[3] + (parts[4] ?? 0);
            const total = parts.reduce((a, b) => a + b, 0);

            const dTotal = total - root.lastTotal;
            const dIdle = idle - root.lastIdle;
            // The first sample has nothing to diff against.
            if (root.lastTotal > 0 && dTotal > 0) {
                root.cpu = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
                const next = [...root.cpuHistory, root.cpu];
                root.cpuHistory = next.slice(-root.historyLength);
            }

            root.lastIdle = idle;
            root.lastTotal = total;
        }
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"

        onLoaded: {
            const fields = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m)
                    fields[m[1]] = parseInt(m[2]);
            }

            const total = fields.MemTotal ?? 0;
            // MemAvailable accounts for reclaimable cache; MemFree alone reports
            // almost everything as used on a machine that has been up a while.
            const available = fields.MemAvailable ?? fields.MemFree ?? 0;
            if (total > 0) {
                root.memTotalKb = total;
                root.memUsedKb = total - available;
                root.memory = root.memUsedKb / total;
            }

            const swapTotal = fields.SwapTotal ?? 0;
            root.swap = swapTotal > 0 ? (swapTotal - (fields.SwapFree ?? 0)) / swapTotal : 0;
        }
    }

    FileView {
        id: tempFile

        // x86_pkg_temp is the package sensor; zone 0 is it on this hardware, but
        // the path is config-overridable because zone numbering is not stable.
        path: "/sys/class/thermal/thermal_zone0/temp"

        onLoaded: {
            const milli = parseInt(text());
            if (!isNaN(milli))
                root.temperature = milli / 1000;
        }
    }
}
