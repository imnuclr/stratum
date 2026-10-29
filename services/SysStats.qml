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
 * gives the average since startup, not the load right now. The same applies per
 * core, so one set of previous counters is kept for the aggregate and one per
 * core line.
 */
Singleton {
    id: root

    property real cpu: 0
    property real memory: 0
    property real swap: 0
    property real temperature: 0

    property int memTotalKb: 0
    property int memUsedKb: 0

    // Shown as "14.6G" rather than a percentage, which is what the strip wants.
    readonly property string memoryShort: `${(memUsedKb / 1048576).toFixed(1)}G`
    readonly property string memoryLabel: `${(memUsedKb / 1048576).toFixed(1)} / ${(memTotalKb / 1048576).toFixed(1)} GiB`

    // Per-core load, in /proc/stat order.
    property var cores: []
    property real frequency: 0
    readonly property string frequencyLabel: frequency > 0 ? `${(frequency / 1000000).toFixed(1)} GHz` : ""

    // Rolling CPU history for the dashboard's dot field, oldest first.
    readonly property int historyLength: 22
    property var cpuHistory: new Array(22).fill(0)

    property int lastIdle: 0
    property int lastTotal: 0
    property var lastCores: ({})

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
        freqFile.reload();
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
            const lines = text().split("\n");
            const nextCores = [];
            const seen = {};

            for (const line of lines) {
                if (!line.startsWith("cpu"))
                    continue;

                const label = line.split(/\s+/)[0];
                const parts = line.split(/\s+/).slice(1).map(Number);
                if (parts.length < 4)
                    continue;

                const idle = parts[3] + (parts[4] ?? 0);
                const total = parts.reduce((a, b) => a + b, 0);

                if (label === "cpu") {
                    const dTotal = total - root.lastTotal;
                    const dIdle = idle - root.lastIdle;
                    // The first sample has nothing to diff against.
                    if (root.lastTotal > 0 && dTotal > 0) {
                        root.cpu = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
                        root.cpuHistory = [...root.cpuHistory, root.cpu].slice(-root.historyLength);
                    }
                    root.lastIdle = idle;
                    root.lastTotal = total;
                } else {
                    const prev = root.lastCores[label];
                    if (prev) {
                        const dTotal = total - prev.total;
                        const dIdle = idle - prev.idle;
                        nextCores.push(dTotal > 0 ? Math.max(0, Math.min(1, 1 - dIdle / dTotal)) : 0);
                    } else {
                        nextCores.push(0);
                    }
                    seen[label] = { idle, total };
                }
            }

            root.lastCores = seen;
            root.cores = nextCores;
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
        // zone numbering is not stable across machines.
        path: "/sys/class/thermal/thermal_zone0/temp"

        onLoaded: {
            const milli = parseInt(text());
            if (!isNaN(milli))
                root.temperature = milli / 1000;
        }
    }

    FileView {
        id: freqFile

        // Core 0 stands in for the package. Reading all sixteen every second to
        // average them costs more than the number is worth.
        path: "/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq"

        onLoaded: {
            const khz = parseInt(text());
            if (!isNaN(khz))
                root.frequency = khz;
        }
    }
}
