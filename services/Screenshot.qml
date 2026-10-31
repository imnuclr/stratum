pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

/*
 * Screen capture via grim, with slurp for a region and satty for annotation.
 *
 * Everything is shelled out through one `sh -c` rather than chained in QML: grim
 * piping into satty is a pipeline, and reproducing it as separate Processes
 * means buffering the image through the shell's memory for no gain.
 *
 * slurp reads its stdin when stdin is not a terminal, taking a list of candidate
 * regions from it, so spawned from the shell — which hands a child a pipe — it
 * blocked on a read that was never going to return. It never connected to
 * Wayland at all and drew nothing, which looked exactly like a screenshot key
 * that did nothing. Every slurp here reads from /dev/null.
 */
Singleton {
    id: root

    readonly property string directory: `${Quickshell.env("HOME")}/Pictures/Screenshots`

    property string lastPath: ""

    /*
     * Nothing is saved until you say so.
     *
     * A capture lands in a temporary file and is put on the clipboard, and the
     * bar at the foot of the screen (modules/osd/ShotBar.qml) offers to save or
     * edit it. Left alone it fades, and the temporary file goes with it — a
     * screenshots folder full of pictures nobody wanted is the thing this
     * avoids. `screenshot.autoSave` puts the old behaviour back.
     */
    property string pending: ""
    property string pendingKind: ""
    property string saved: ""
    readonly property bool offering: root.pending.length > 0
    readonly property string tempDir: Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp"

    function tempFor(kind) {
        return `${root.tempDir}/stratum-shot-${kind}-${root.stamp()}.png`;
    }

    function offer(path, kind) {
        if (Config.get("screenshot.autoSave", false)) {
            root.keep(path, kind);
            return;
        }
        root.saved = "";
        root.pendingKind = kind;
        root.pending = path;
        root.remaining = 1;
    }

    // Into the screenshots folder, under its own name.
    function keep(path, kind) {
        const dest = `${root.directory}/${kind}-${root.stamp()}.png`;
        root.saved = dest;
        root.lastPath = dest;
        keeper.command = ["sh", "-c", `mkdir -p '${root.directory}' && mv -f "$1" '${dest}'`, "sh", path];
        keeper.running = true;
        root.pending = "";
    }

    function keepPending() {
        if (root.offering)
            root.keep(root.pending, root.pendingKind);
    }

    // Into satty, which owns saving from there.
    function editPending() {
        if (!root.offering)
            return;
        const dest = `${root.directory}/edit-${root.stamp()}.png`;
        editor.command = ["sh", "-c",
            `mkdir -p '${root.directory}'; satty --filename "$1" --copy-command '${root.copy}' --output-filename '${dest}'; rm -f "$1"`,
            "sh", root.pending];
        editor.running = true;
        root.pending = "";
    }

    // Left alone, or waved away: the temporary file goes too.
    function dropPending() {
        if (!root.offering)
            return;
        dropper.command = ["rm", "-f", root.pending];
        dropper.running = true;
        root.pending = "";
    }

    // Held open while the pointer is on the bar.
    property bool held: false

    /*
     * How much of the wait is left, 1 to 0, which is both the line drawn on the
     * bar and what throws the capture away at the end. One clock for both: as a
     * line animating on its own beside a timer, the two could disagree — the
     * line ran out while the bar stayed, and could draw wider than the bar it
     * was drawn in.
     */
    property real remaining: 0

    // Nothing to hold open once it has gone.
    onOfferingChanged: {
        if (!root.offering) {
            root.held = false;
            root.remaining = 0;
        }
    }

    Timer {
        interval: 40
        repeat: true
        running: root.offering && !root.held

        onTriggered: {
            root.remaining -= 40 / Math.max(400, Config.get("screenshot.offerMs", 2000));
            if (root.remaining <= 0)
                root.dropPending();
        }
    }

    Process {
        id: keeper
    }

    Process {
        id: editor
    }

    Process {
        id: dropper
    }

    /*
     * Held for the lifetime of the capture, so a second press cannot start a
     * second selector while one is already waiting. Releasing it after a moment
     * instead — which is what it did before — let two presses stack two slurps,
     * and two selectors competing for the pointer meant neither ever resolved:
     * one sat waiting for a selection for a quarter of an hour.
     *
     * The watchdog is what stops that becoming the other failure, where anything
     * ending the capture without a clean exit latched the flag and every
     * screenshot afterwards was dropped in silence. Generous, because a region
     * selection legitimately waits as long as the person takes.
     */
    property bool busy: false

    // What the capture in flight is: screen, region or window.
    property string kind: "screen"

    /*
     * Pasted as well as saved. A screenshot is usually wanted somewhere else
     * immediately, and hunting for the file afterwards is the slow path.
     */
    readonly property string copy: "wl-copy --type image/png"

    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
    }

    /*
     * Freeze, then select.
     *
     * A region is picked on a still image of the screen rather than on the live
     * one, so what is captured is what was on screen when the key was pressed —
     * a video frame or a notification that would be gone by the time the
     * selection is finished is still there to be picked.
     *
     * The screen is grabbed first and shown in an overlay (modules/Freeze.qml),
     * slurp then runs on top of it, and grim captures through it: the overlay is
     * part of what the compositor draws, so the crop comes out of the frozen
     * frame. No extra tool needed. If the grab fails the selection simply runs on
     * the live screen as it did before.
     */
    property string freezeOutput: ""
    property url freezeSource: ""
    property string pendingScript: ""
    readonly property string freezeFile: `${Quickshell.env("XDG_RUNTIME_DIR") ?? "/tmp"}/stratum-freeze.png`

    /*
     * From a button in a panel: the panel has to be gone before the screen is
     * grabbed, or its closing fade is in the picture.
     */
    function regionSoon() {
        Shell.close();
        soon.restart();
    }

    Timer {
        id: soon

        interval: 380
        onTriggered: root.region()
    }

    function runFrozen(script, path) {
        if (root.busy) {
            Diag.log("screenshot", "ignored: a capture is already waiting");
            return;
        }
        const output = Hypr.focusedWorkspace?.monitor?.name ?? "";
        if (output.length === 0) {
            root.run(script, path);
            return;
        }
        root.busy = true;
        watchdog.restart();
        root.lastPath = path;
        // Let the key release and the compositor settle before the selector is up.
        root.pendingScript = `mkdir -p '${root.directory}'; sleep 0.05; ${script}`;
        grabber.output = output;
        grabber.command = ["grim", "-o", output, root.freezeFile];
        grabber.running = true;
    }

    // The overlay reports the frozen image is on screen; give the compositor a
    // moment to present it before the selector appears above it.
    function freezeShown() {
        settle.restart();
    }

    function startPending() {
        if (root.pendingScript.length === 0)
            return;
        capture.command = ["sh", "-c", root.pendingScript];
        root.pendingScript = "";
        Diag.log("screenshot", `running frozen: ${capture.command[2]}`);
        capture.running = true;
    }

    function endFreeze() {
        root.freezeOutput = "";
        root.freezeSource = "";
        settle.stop();
        cleanup.running = true;
    }

    Process {
        id: grabber

        property string output: ""

        onExited: (code, status) => {
            if (code === 0) {
                root.freezeSource = `file://${root.freezeFile}`;
                root.freezeOutput = grabber.output;
                // If the overlay never reports in, select on the live screen.
                giveUp.restart();
            } else {
                Diag.log("screenshot", `freeze grab failed code=${code}; selecting live`);
                root.startPending();
            }
        }
    }

    Timer {
        id: settle

        interval: 140
        onTriggered: {
            giveUp.stop();
            root.startPending();
        }
    }

    Timer {
        id: giveUp

        interval: 2000
        onTriggered: root.startPending()
    }

    Process {
        id: cleanup

        command: ["rm", "-f", root.freezeFile]
    }

    function run(script, path) {
        if (root.busy) {
            Diag.log("screenshot", "ignored: a capture is already waiting");
            return;
        }
        root.busy = true;
        watchdog.restart();
        root.lastPath = path;
        capture.command = ["sh", "-c", `mkdir -p '${root.directory}'; ${script}`];
        Diag.log("screenshot", `running: ${script}`);
        capture.running = true;
    }

    // Whole output under the pointer, not every output: a capture spanning two
    // monitors is rarely what is wanted and is always enormous.
    function screen() {
        const path = root.tempFor("screen");
        root.kind = "screen";
        root.run(`grim -o "$(hyprctl -j activeworkspace | sed -n 's/.*\\"monitor\\": \\"\\([^\\"]*\\)\\".*/\\1/p')" '${path}' && ${root.copy} <'${path}' && echo READY`, path);
    }

    function region() {
        const path = root.tempFor("region");
        root.kind = "region";
        // slurp exits non-zero when cancelled, which must not leave an empty file.
        root.runFrozen(`geom=$(slurp -d </dev/null) || exit 0; sleep 0.08; grim -g "$geom" '${path}' && ${root.copy} <'${path}' && echo READY`, path);
    }

    function window() {
        const path = root.tempFor("window");
        root.kind = "window";
        root.run(`geom=$(hyprctl -j activewindow | python3 -c 'import json,sys; w=json.load(sys.stdin); print(f"{w[\\"at\\"][0]},{w[\\"at\\"][1]} {w[\\"size\\"][0]}x{w[\\"size\\"][1]}")'); grim -g "$geom" '${path}' && ${root.copy} <'${path}' && echo READY`, path);
    }

    // Straight to the annotator; satty owns saving from there.
    function annotate() {
        const path = `${root.directory}/edit-${root.stamp()}.png`;
        root.runFrozen(`geom=$(slurp -d </dev/null) || exit 0; sleep 0.08; grim -g "$geom" - | satty --filename - --copy-command '${root.copy}' --output-filename '${path}'`, path);
    }

    Process {
        id: capture

        // READY, printed by the script once the file is written and copied.
        property bool ready: false

        stdout: StdioCollector {
            onStreamFinished: capture.ready = text.includes("READY")
        }

        // Anything the tools complain about, in the trace. Without this a capture
        // that started and did nothing gave no reason at all.
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    Diag.log("screenshot", `stderr: ${text.trim()}`);
            }
        }

        onExited: (code, status) => {
            Diag.log("screenshot", `exited code=${code} status=${status} path=${root.lastPath}`);
            watchdog.stop();
            root.busy = false;
            root.endFreeze();
            if (code === 0 && capture.ready && root.lastPath.startsWith(root.tempDir))
                root.offer(root.lastPath, root.kind);
            capture.ready = false;
        }
    }

    /*
     * The capture can outlive the process that started it — slurp waits for a
     * selection for as long as it takes — so the guard is released on a timer
     * rather than on exit alone. Short enough that a cancelled selection does not
     * block the next attempt for long.
     */
    Timer {
        id: watchdog

        interval: 120000
        onTriggered: {
            Diag.log("screenshot", "watchdog fired: releasing a capture that never exited");
            root.busy = false;
            root.endFreeze();
        }
    }
}
