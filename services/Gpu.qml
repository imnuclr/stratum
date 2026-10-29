pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * NVIDIA GPU load, temperature and memory, via nvidia-smi.
 *
 * There is no sysfs path for utilisation on the proprietary driver, so this
 * shells out. The process is cheap but not free, so it only runs while
 * something is reading it, and `available` stays false on machines without the
 * tool so consumers can hide rather than show zeros.
 */
Singleton {
    id: root

    property bool available: false
    property real usage: 0
    property real temperature: 0
    property real memoryUsed: 0
    property real memoryTotal: 0

    readonly property real memory: memoryTotal > 0 ? memoryUsed / memoryTotal : 0

    property int watchers: 0

    function watch() {
        root.watchers++;
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
    }

    Timer {
        running: root.watchers > 0
        repeat: true
        triggeredOnStart: true
        interval: 2000
        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
    }

    Process {
        id: probe

        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits"]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(",").map(s => parseFloat(s));
                if (parts.length < 4 || parts.some(isNaN)) {
                    root.available = false;
                    return;
                }
                root.usage = parts[0] / 100;
                root.temperature = parts[1];
                root.memoryUsed = parts[2];
                root.memoryTotal = parts[3];
                root.available = true;
            }
        }
    }
}
