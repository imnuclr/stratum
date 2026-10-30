pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*
 * The handful of processes using the most of one thing: processor, memory, or
 * graphics. The dashboard's processes list switches between them.
 *
 * ps reports pcpu as an average over each process's whole lifetime, not an
 * instantaneous rate, so a process that was busy at launch keeps a high figure
 * for a while. That is close enough for "what is this machine doing".
 *
 * Graphics comes from nvidia-smi on NVIDIA, and elsewhere from the counters the
 * kernel keeps per open GPU handle (/proc/<pid>/fdinfo, amdgpu and i915): busy
 * time sampled twice half a second apart, as a share of that half second.
 */
Singleton {
    id: root

    property var top: []
    readonly property int count: 4

    // "cpu", "memory" or "gpu", remembered between sessions.
    readonly property string mode: Config.get("dashboard.processes", "cpu")

    function setMode(m) {
        Config.set("dashboard.processes", m);
    }

    onModeChanged: {
        root.top = [];
        root.poll();
    }

    property int watchers: 0

    function watch() {
        root.watchers++;
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
    }

    function poll() {
        if (root.watchers === 0 || probe.running)
            return;
        probe.command = root.commandFor(root.mode);
        probe.running = true;
    }

    function commandFor(mode) {
        if (mode === "memory")
            return ["sh", "-c", "ps -eo comm,pmem --sort=-pmem --no-headers | head -n 12"];
        if (mode === "gpu")
            return ["sh", "-c", `
                if command -v nvidia-smi >/dev/null 2>&1; then
                    nvidia-smi pmon -c 1 -s u 2>/dev/null | awk '!/^#/ && $4 ~ /^[0-9]+$/ { print $NF, $4 }'
                    exit 0
                fi
                snap() {
                    grep -s -H '^drm-engine-[a-z0-9-]*:' /proc/[0-9]*/fdinfo/* 2>/dev/null \\
                        | awk -F'[/: \\t]+' '{ s[$3] += $(NF-1) } END { for (p in s) print p, s[p] }'
                }
                a=$(snap); sleep 0.5; b=$(snap)
                printf '%s\\n%s\\n' "$a" "--" "$b" | awk '
                    $1 == "--" { second = 1; next }
                    !second { before[$1] = $2; next }
                    { d = ($2 - before[$1]) / 5000000; if (d > 0.05) print $1, d }' \\
                | while read -r pid pct; do
                    printf '%s %s\\n' "$(cat /proc/$pid/comm 2>/dev/null || echo "$pid")" "$pct"
                done`];
        return ["sh", "-c", "ps -eo comm,pcpu --sort=-pcpu --no-headers | head -n 12"];
    }

    Timer {
        running: root.watchers > 0
        repeat: true
        triggeredOnStart: true
        interval: 3000
        onTriggered: root.poll()
    }

    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: {
                // One row per program: several processes of one browser are
                // one browser.
                const sums = {};
                for (const line of text.split("\n")) {
                    const m = line.trim().match(/^(.*?)\s+([\d.]+)$/);
                    if (!m)
                        continue;
                    const v = parseFloat(m[2]);
                    if (v < 0.1)
                        continue;
                    sums[m[1]] = (sums[m[1]] ?? 0) + v;
                }
                root.top = Object.keys(sums)
                    .map(name => ({ name: name, usage: Math.min(1, sums[name] / 100) }))
                    .sort((a, b) => b.usage - a.usage)
                    .slice(0, root.count);
            }
        }
    }
}
