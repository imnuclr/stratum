pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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
    property bool busy: false

    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
    }

    function run(script, path) {
        if (root.busy)
            return;
        root.busy = true;
        root.lastPath = path;
        capture.command = ["sh", "-c", `mkdir -p '${root.directory}'; ${script}`];
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

        onExited: root.busy = false
    }
}
