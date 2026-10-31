pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * What the machine is drawing, in watts.
 *
 * Taken from whatever this machine will say: the battery's own meter on a
 * laptop, the processor package through powercap, and the graphics card through
 * nvidia-smi. Each is optional, so a desktop with an NVIDIA card reports the
 * card and the processor, and a laptop on battery reports the whole machine.
 *
 * powercap counts energy rather than power, so it is read twice a second apart
 * and the difference is the wattage.
 */
Singleton {
    id: root

    property real battery: -1
    property real cpu: -1
    property real gpu: -1

    readonly property bool available: root.total > 0
    // The battery's figure already covers the whole machine; otherwise the
    // parts are added up.
    readonly property real total: root.battery > 0
        ? root.battery
        : Math.max(0, (root.cpu > 0 ? root.cpu : 0) + (root.gpu > 0 ? root.gpu : 0))

    readonly property string label: root.battery > 0 ? "from battery"
        : (root.cpu > 0 && root.gpu > 0 ? "cpu + gpu"
            : (root.gpu > 0 ? "gpu" : (root.cpu > 0 ? "cpu" : "")))

    // Something to measure the ring against: a sensible full scale for this
    // machine, grown if it is ever passed.
    property real ceiling: 120
    onTotalChanged: {
        if (root.total > root.ceiling)
            root.ceiling = Math.ceil(root.total / 50) * 50;
    }
    readonly property real fraction: root.ceiling > 0 ? Math.min(1, root.total / root.ceiling) : 0

    property int watchers: 0

    function watch() {
        root.watchers++;
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
    }

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
        interval: root.watchers > 0 ? 4000 : 12000
        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
    }

    Process {
        id: probe

        command: ["sh", "-c", `
            # The battery, discharging: microwatts, or amps times volts.
            for b in /sys/class/power_supply/BAT*; do
                [ -d "$b" ] || continue
                [ "$(cat "$b/status" 2>/dev/null)" = Discharging ] || continue
                if [ -r "$b/power_now" ]; then
                    echo "battery=$(cat "$b/power_now")"
                elif [ -r "$b/current_now" ] && [ -r "$b/voltage_now" ]; then
                    echo "battery=$(( $(cat "$b/current_now") * $(cat "$b/voltage_now") / 1000000 ))"
                fi
                break
            done
            # The processor package, as energy counted over one second.
            for z in /sys/class/powercap/*:0 /sys/class/powercap/*rapl*/; do
                [ -r "$z/energy_uj" ] || continue
                a=$(cat "$z/energy_uj"); sleep 1; b=$(cat "$z/energy_uj")
                [ "$b" -ge "$a" ] && echo "cpu=$(( b - a ))"
                break
            done
            command -v nvidia-smi >/dev/null 2>&1 &&
                echo "gpu=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits 2>/dev/null | head -n1)"
            true`]

        stdout: StdioCollector {
            onStreamFinished: {
                let battery = -1, cpu = -1, gpu = -1;
                for (const line of text.split("\n")) {
                    const at = line.indexOf("=");
                    if (at < 0)
                        continue;
                    const v = parseFloat(line.slice(at + 1));
                    if (isNaN(v))
                        continue;
                    const key = line.slice(0, at);
                    // Microwatts and microjoules-per-second both become watts.
                    if (key === "battery")
                        battery = v / 1000000;
                    else if (key === "cpu")
                        cpu = v / 1000000;
                    else if (key === "gpu")
                        gpu = v;
                }
                root.battery = battery;
                root.cpu = cpu;
                root.gpu = gpu;
            }
        }
    }
}
