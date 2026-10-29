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
 */
Singleton {
    id: root

    readonly property string directory: `${Quickshell.env("HOME")}/Pictures/Screenshots`

    property string lastPath: ""

    /*
     * Guards against one keypress firing twice, not against taking another
     * screenshot. This used to be a plain `busy` flag held for the lifetime of
     * the capture, which latched: anything that stopped the process without a
     * clean exit left it true and every screenshot afterwards was silently
     * dropped until the shell restarted.
     */
    property bool busy: false

    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
    }

    function run(script, path) {
        if (root.busy)
            return;
        root.busy = true;
        unlatch.restart();
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
        root.run(`geom=$(slurp -d) || exit 0; grim -g "$geom" '${path}'`, path);
    }

    function window() {
        const path = `${root.directory}/window-${root.stamp()}.png`;
        root.run(`geom=$(hyprctl -j activewindow | python3 -c 'import json,sys; w=json.load(sys.stdin); print(f"{w[\\"at\\"][0]},{w[\\"at\\"][1]} {w[\\"size\\"][0]}x{w[\\"size\\"][1]}")'); grim -g "$geom" '${path}'`, path);
    }

    // Straight to the annotator; satty owns saving from there.
    function annotate() {
        const path = `${root.directory}/edit-${root.stamp()}.png`;
        root.run(`geom=$(slurp -d) || exit 0; grim -g "$geom" - | satty --filename - --output-filename '${path}'`, path);
    }

    Process {
        id: capture

        onExited: (code, status) => {
            Diag.log("screenshot", `exited code=${code} status=${status} path=${root.lastPath}`);
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
        id: unlatch

        interval: 600
        onTriggered: root.busy = false
    }
}
