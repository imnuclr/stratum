pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * GPU load, temperature and memory, from whichever GPU this machine has.
 *
 * NVIDIA has no sysfs path for utilisation, so that one shells out to
 * nvidia-smi. AMD publishes busy percentage, VRAM and temperature in sysfs. Intel
 * publishes none of load, so its clock is read instead: how far the GPU has
 * clocked up between its minimum and maximum is a fair stand-in for how hard it
 * is working, though it says nothing of temperature or memory (shared with the
 * system). One probe script tries them in that order and prints the same four
 * numbers whichever answered, so `available` stays false only when none did.
 *
 * Costs nothing unless read: it only runs while something is watching.
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

        command: ["sh", "-c", `
            if command -v nvidia-smi >/dev/null 2>&1; then
                nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null && exit 0
            fi
            for d in /sys/class/drm/card[0-9]*/device; do
                [ -r "$d/gpu_busy_percent" ] || continue
                busy=$(cat "$d/gpu_busy_percent")
                t=$(cat "$d"/hwmon/hwmon*/temp1_input 2>/dev/null | head -n1)
                used=$(cat "$d/mem_info_vram_used" 2>/dev/null || echo 0)
                total=$(cat "$d/mem_info_vram_total" 2>/dev/null || echo 0)
                echo "$busy,$(( \${t:-0} / 1000 )),$(( used / 1048576 )),$(( total / 1048576 ))"
                exit 0
            done
            # Intel on the xe driver (Lunar Lake, Battlemage and later): the clock
            # lives under the tile, and act_freq reads 0 while the GPU is idle.
            for f in /sys/class/drm/card[0-9]*/device/tile[0-9]*/gt0/freq0; do
                [ -r "$f/act_freq" ] || continue
                cur=$(cat "$f/act_freq")
                max=$(cat "$f/rp0_freq" 2>/dev/null || cat "$f/max_freq")
                min=$(cat "$f/rpn_freq" 2>/dev/null || cat "$f/min_freq")
                span=$(( \${max:-0} - \${min:-0} ))
                [ "$span" -gt 0 ] || continue
                pct=$(( (cur > min ? cur - min : 0) * 100 / span ))
                [ "$pct" -gt 100 ] && pct=100
                t=$(cat \${f%/tile*}/hwmon/hwmon*/temp*_input 2>/dev/null | sort -n | tail -n1)
                echo "$pct,$(( \${t:-0} / 1000 )),0,0"
                exit 0
            done
            for c in /sys/class/drm/card[0-9]*; do
                for g in "$c/gt/gt0" "$c"; do
                    cur=$(cat "$g/rps_cur_freq_mhz" "$g/gt_cur_freq_mhz" 2>/dev/null | head -n1)
                    [ -n "$cur" ] || continue
                    max=$(cat "$g/rps_max_freq_mhz" "$g/gt_max_freq_mhz" 2>/dev/null | head -n1)
                    min=$(cat "$g/rps_min_freq_mhz" "$g/gt_min_freq_mhz" 2>/dev/null | head -n1)
                    span=$(( \${max:-0} - \${min:-0} ))
                    [ "$span" -gt 0 ] || continue
                    pct=$(( (cur - min) * 100 / span ))
                    [ "$pct" -lt 0 ] && pct=0
                    echo "$pct,0,0,0"
                    exit 0
                done
            done
            exit 1
        `]

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
