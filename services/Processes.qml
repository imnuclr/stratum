pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * The handful of processes currently using the most CPU.
 *
 * ps reports pcpu as an average over each process's whole lifetime, not an
 * instantaneous rate, so a process that was busy at launch keeps a high figure
 * for a while. That is close enough for "what is this machine doing", and the
 * alternative is tracking per-pid jiffies across samples for a list that is
 * glanced at.
 */
Singleton {
    id: root

    property var top: []
    readonly property int count: 4

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
        interval: 3000
        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
    }

    Process {
        id: probe

        command: ["ps", "-eo", "comm,pcpu", "--sort=-pcpu", "--no-headers"]

        stdout: StdioCollector {
            onStreamFinished: {
                const rows = [];
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/^(.*?)\s+([\d.]+)$/);
                    if (!m)
                        continue;
                    const pcpu = parseFloat(m[2]);
                    // Idle processes outnumber busy ones; stop once they stop
                    // being worth a row.
                    if (pcpu < 0.1)
                        break;
                    rows.push({ name: m[1], usage: pcpu / 100 });
                    if (rows.length >= root.count)
                        break;
                }
                root.top = rows;
            }
        }
    }
}
