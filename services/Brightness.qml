pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Display brightness, one level per display.
 *
 * External monitors have no /sys/class/backlight to write — ddcutil talks to
 * them over I2C instead, which is slow enough to matter: a single setvcp takes a
 * good fraction of a second, and firing one per slider frame queues them up until
 * the control feels detached from the pointer. So each display's level is held
 * locally and applied on a debounce; the UI follows the local value immediately
 * and the monitor catches up.
 *
 * A laptop is the other case: an internal panel has a backlight device and no DDC
 * at all, so brightnessctl is used there and the ddcutil path is skipped
 * entirely. Which one applies is decided by whether a backlight device exists
 * rather than by guessing at the hardware.
 */
Singleton {
    id: root

    // VCP 10 is the standard brightness feature code.
    readonly property string feature: "10"

    /*
     * One entry per display: { id, label, value }. `id` is a ddcutil display
     * number, or the backlight device name on a laptop. Replaced wholesale rather
     * than mutated, because QML does not see writes into an existing array.
     */
    property var displays: []

    property bool ready: false
    property bool applying: false

    // Set once the backlight probe has looked. Until then neither path writes, so
    // a laptop never pays for the I2C scan it cannot use.
    property string backlight: ""
    readonly property bool internal: backlight.length > 0

    // The first display, for anything that wants a single number.
    readonly property real value: displays.length > 0 ? displays[0].value : 0.5

    function indexOf(id) {
        for (let i = 0; i < displays.length; i++)
            if (displays[i].id === id)
                return i;
        return -1;
    }

    function setFor(id, v) {
        const i = root.indexOf(id);
        if (i < 0)
            return;
        const next = [...root.displays];
        next[i] = { id: next[i].id, label: next[i].label, value: Math.max(0, Math.min(1, v)) };
        root.displays = next;
        pendingIds[id] = true;
        debounce.restart();
    }

    /*
     * Key steps on a laptop panel: 1, 2, 3, 4, 6, 8, 10 at the dim end, where a
     * single percent is the difference between dark and just visible, and an even
     * 2% from there up (12, 14, 16 ... 100). The step is always to the next stop,
     * so the numbers land on round values whichever way you are going and whatever
     * the slider left it at. External monitors just move by the step they are given.
     */
    readonly property var stops: [1, 2, 3, 4, 6, 8, 10].concat(Array.from({ length: 45 }, (_, i) => 12 + i * 2))

    function stepFor(id, delta) {
        const i = root.indexOf(id);
        if (i < 0)
            return;
        const now = root.displays[i].value;
        if (!root.internal) {
            root.setFor(id, now + delta);
            return;
        }
        const percent = now * 100;
        let target;
        if (delta > 0) {
            target = root.stops.find(s => s > percent + 0.5) ?? 100;
        } else {
            target = 1;
            for (const s of root.stops)
                if (s < percent - 0.5)
                    target = s;
        }
        root.setFor(id, target / 100);
    }

    /*
     * Which ddcutil display is which Hyprland output.
     *
     * ddcutil reports a monitor's model from its EDID and Hyprland reports the
     * same string, so the two line up exactly — "XG22VA" against HDMI-A-1,
     * "34E6UC" against DP-2 here. An earlier note called this guesswork and left
     * every display sharing one control; it is not guesswork, it is the same
     * field read twice. A laptop panel has no model to match and is the only
     * display anyway, so it answers for everything.
     */
    // Wayland's own output info, rather than Hyprland's. Hyprland reports the
    // model for one of these two outputs and not the other, for reasons that do
    // not matter: the compositor is not the only one holding the EDID, and the
    // screen object the panel is already built around carries it.
    function modelFor(name) {
        return Quickshell.screens.find(s => s.name === name)?.model ?? "";
    }

    function forMonitor(name) {
        if (root.internal)
            return root.displays.length > 0 ? root.displays[0] : null;

        const model = root.modelFor(name);
        if (model)
            for (const d of root.displays)
                if (d.label === model)
                    return d;

        // Nothing matched: better one display's brightness than a dead control.
        return root.displays.length > 0 ? root.displays[0] : null;
    }

    function valueFor(name) {
        return root.forMonitor(name)?.value ?? 0.5;
    }

    function setForMonitor(name, v) {
        const d = root.forMonitor(name);
        if (d)
            root.setFor(d.id, v);
    }

    function stepForMonitor(name, delta) {
        const d = root.forMonitor(name);
        if (d)
            root.setFor(d.id, d.value + delta);
    }

    // Keys still move every display together: a brightness key is not aimed at
    // anything, and per-display control lives where the pointer already is.
    function set(v) {
        for (const d of root.displays)
            root.setFor(d.id, v);
    }

    function step(delta) {
        for (const d of root.displays)
            root.stepFor(d.id, delta);
    }

    // Which displays have an unwritten change. Plain object, not a model: it is
    // only ever read by the debounce below.
    readonly property var pendingIds: ({})

    Timer {
        id: debounce

        // Long enough to collapse a drag into one write, short enough that a
        // single click still feels immediate.
        interval: 180
        onTriggered: {
            if (!root.ready)
                return;
            const writes = [];
            for (const d of root.displays) {
                if (!root.pendingIds[d.id])
                    continue;
                delete root.pendingIds[d.id];
                const level = Math.round(d.value * 100);
                writes.push(root.internal
                    ? `brightnessctl --device ${d.id} set ${level}%`
                    : `ddcutil --brief --display ${d.id} setvcp ${root.feature} ${level}`);
            }
            if (writes.length === 0)
                return;
            // Chained in one shell rather than run in parallel: concurrent I2C
            // writes to different buses collide.
            apply.command = ["sh", "-c", writes.join("; ")];
            apply.running = true;
        }
    }

    Process {
        id: apply

        onRunningChanged: root.applying = running
    }

    /*
     * Looks for an internal panel first, because its answer decides whether the
     * ddcutil probes run at all.
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
                if (isNaN(current) || !(max > 0))
                    return;
                root.displays = [{ id: root.backlight, label: "internal", value: current / max }];
                root.ready = true;
            }
        }
    }

    /*
     * Enumerates the external displays and their current levels in one shell.
     * detect walks every I2C bus and takes the better part of half a minute, so
     * it runs once and the getvcp for each display is chained onto it rather than
     * paying for a second walk.
     */
    Process {
        id: detect

        running: !root.internal && backlightProbe.exited
        command: ["sh", "-c",
            "ddcutil detect --brief | awk '/^Display /{d=$2} /Monitor:/{print d\"\\t\"$2}' | " +
            "while IFS=$'\\t' read -r d m; do " +
            "  printf '%s\\t%s\\t%s\\n' \"$d\" \"$m\" \"$(ddcutil --brief --display \"$d\" getvcp 10 2>/dev/null)\"; " +
            "done"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const cols = line.split("\t");
                    if (cols.length < 3)
                        continue;
                    const id = parseInt(cols[0]);
                    // "VCP 10 C <current> <max>"
                    const vcp = cols[2].trim().split(/\s+/);
                    const current = parseInt(vcp[3]);
                    const max = parseInt(vcp[4]);
                    if (isNaN(id) || isNaN(current) || !(max > 0))
                        continue;
                    // "WAM:XG22VA:" — the middle field is the model.
                    const parts = cols[1].split(":");
                    const label = (parts.length > 1 && parts[1].length > 0 ? parts[1] : cols[1]).trim();
                    found.push({ id: id, label: label, value: current / max });
                }
                if (found.length === 0)
                    return;
                root.displays = found;
                root.ready = true;
            }
        }
    }
}
