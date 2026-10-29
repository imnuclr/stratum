pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Monitor brightness over DDC/CI.
 *
 * These are external displays, so there is no /sys/class/backlight to write —
 * ddcutil talks to the monitor over I2C instead. That is slow enough to matter:
 * a single setvcp takes a good fraction of a second, and firing one per slider
 * frame queues them up until the control feels detached from the pointer.
 *
 * So the value is held locally and applied on a debounce. The UI follows the
 * local value immediately and the monitor catches up.
 */
Singleton {
    id: root

    // 0..1, the value the UI shows.
    property real value: 0.5
    property bool ready: false
    property bool applying: false

    // VCP 10 is the standard brightness feature code.
    readonly property string feature: "10"

    function set(v) {
        root.value = Math.max(0, Math.min(1, v));
        debounce.restart();
    }

    function step(delta) {
        root.set(root.value + delta);
    }

    Timer {
        id: debounce

        // Long enough to collapse a drag into one write, short enough that a
        // single click still feels immediate.
        interval: 180
        onTriggered: {
            if (!root.ready)
                return;
            apply.command = ["ddcutil", "--brief", "setvcp", root.feature,
                `${Math.round(root.value * 100)}`];
            apply.running = true;
        }
    }

    Process {
        id: apply

        onRunningChanged: root.applying = running
    }

    // Read once at startup. Polling would mean an I2C round trip per tick for a
    // value that only this shell changes.
    Process {
        id: probe

        running: true
        command: ["ddcutil", "--brief", "getvcp", root.feature]

        stdout: StdioCollector {
            onStreamFinished: {
                // Brief format: "VCP 10 C <current> <max>"
                const parts = text.trim().split(/\s+/);
                const current = parseInt(parts[3]);
                const max = parseInt(parts[4]);
                if (!isNaN(current) && max > 0) {
                    root.value = current / max;
                    root.ready = true;
                }
            }
        }
    }
}
