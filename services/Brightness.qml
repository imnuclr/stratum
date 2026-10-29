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
 *
 * A laptop is the other case: an internal panel has /sys/class/backlight and no
 * DDC at all, so brightnessctl is used there instead and the ddcutil path is
 * skipped entirely. Which one applies is decided by whether a backlight device
 * exists, not by guessing at the hardware.
 *
 * Every display gets the write. ddcutil with no --display talks to the first one
 * it finds, which on a two-monitor desk means the slider moved one screen and
 * left the other alone. The writes are chained in one shell rather than run in
 * parallel because concurrent I2C writes to different buses collide.
 */
Singleton {
    id: root

    // 0..1, the value the UI shows.
    property real value: 0.5
    property bool ready: false
    property bool applying: false

    // VCP 10 is the standard brightness feature code.
    readonly property string feature: "10"

    /*
     * Display numbers as ddcutil counts them. Assumed to be just the first until
     * the detect finishes, because detect walks every I2C bus and takes the
     * better part of half a minute — too long to hold the slider dead for.
     */
    property var displays: [1]

    // Set once the backlight probe has looked; until then neither path writes,
    // which avoids a laptop taking a pointless ddcutil round trip on startup.
    property string backlight: ""
    readonly property bool internal: backlight.length > 0

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
            const level = Math.round(root.value * 100);
            if (root.internal) {
                apply.command = ["brightnessctl", "--device", root.backlight,
                    "set", `${level}%`];
            } else {
                const writes = root.displays.map(d =>
                    `ddcutil --brief --display ${d} setvcp ${root.feature} ${level}`);
                apply.command = ["sh", "-c", writes.join("; ")];
            }
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

        running: !root.internal && backlightProbe.exited
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

    // Runs once, in the background, and widens `displays` when it lands.
    Process {
        id: detect

        running: !root.internal && backlightProbe.exited
        command: ["ddcutil", "detect", "--brief"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const m = line.match(/^Display\s+(\d+)/);
                    if (m)
                        found.push(parseInt(m[1]));
                }
                if (found.length > 0)
                    root.displays = found;
            }
        }
    }

    /*
     * Looks for an internal panel first, because its answer decides whether the
     * ddcutil probes run at all. `exited` gates them rather than a timer: they
     * must not start before this has reported, or a laptop would still pay for
     * the I2C scan it does not need.
     */
    Process {
        id: backlightProbe

        property bool exited: false

        running: true
        command: ["sh", "-c", "ls -1 /sys/class/backlight 2>/dev/null | head -1"]

        onExited: exited = true

        stdout: StdioCollector {
            onStreamFinished: {
                const name = text.trim();
                if (name.length === 0)
                    return;
                root.backlight = name;
                readInternal.command = ["sh", "-c",
                    `cat /sys/class/backlight/${name}/brightness /sys/class/backlight/${name}/max_brightness`];
                readInternal.running = true;
            }
        }
    }

    Process {
        id: readInternal

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                const current = parseInt(parts[0]);
                const max = parseInt(parts[1]);
                if (!isNaN(current) && max > 0) {
                    root.value = current / max;
                    root.ready = true;
                }
            }
        }
    }
}
