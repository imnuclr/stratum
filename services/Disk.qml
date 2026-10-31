pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * How full the disk the system is on is, as 0 to 1.
 *
 * Read only while something is watching, and no more often than a disk fills.
 */
Singleton {
    id: root

    property real used: 0
    property bool available: false
    property int watchers: 0

    function watch() {
        root.watchers++;
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
    }

    // Widgets on an energy saver: kept running, at the slow tick.
    property int slowWatchers: 0

    function watchSlowly() {
        root.slowWatchers++;
    }

    function unwatchSlowly() {
        root.slowWatchers = Math.max(0, root.slowWatchers - 1);
    }

    Timer {
        running: root.watchers > 0 || root.slowWatchers > 0
        repeat: true
        triggeredOnStart: true
        interval: 60000
        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
    }

    Process {
        id: probe

        command: ["sh", "-c", "df -P / | awk 'NR==2 { gsub(\"%\", \"\", $5); print $5 }'"]

        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat(text.trim());
                root.available = !isNaN(v);
                if (root.available)
                    root.used = v / 100;
            }
        }
    }
}
