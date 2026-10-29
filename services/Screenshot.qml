pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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

    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
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
        const path = `${root.directory}/screen-${root.stamp()}.png`;
        root.run(`grim -o "$(hyprctl -j activeworkspace | sed -n 's/.*\\"monitor\\": \\"\\([^\\"]*\\)\\".*/\\1/p')" '${path}'`, path);
    }

    function region() {
        const path = `${root.directory}/region-${root.stamp()}.png`;
        // slurp exits non-zero when cancelled, which must not leave an empty file.
        root.run(`geom=$(slurp -d </dev/null) || exit 0; grim -g "$geom" '${path}'`, path);
    }

    function window() {
        const path = `${root.directory}/window-${root.stamp()}.png`;
        root.run(`geom=$(hyprctl -j activewindow | python3 -c 'import json,sys; w=json.load(sys.stdin); print(f"{w[\\"at\\"][0]},{w[\\"at\\"][1]} {w[\\"size\\"][0]}x{w[\\"size\\"][1]}")'); grim -g "$geom" '${path}'`, path);
    }

    // Straight to the annotator; satty owns saving from there.
    function annotate() {
        const path = `${root.directory}/edit-${root.stamp()}.png`;
        root.run(`geom=$(slurp -d </dev/null) || exit 0; grim -g "$geom" - | satty --filename - --output-filename '${path}'`, path);
    }

    Process {
        id: capture

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
        }
    }
}
