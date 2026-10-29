pragma Singleton

import QtQuick
import Quickshell
import qs.config

/*
 * Tracing for the things that only happen under a real pointer or a real
 * keypress, which cannot be reproduced from a script: hover enter and leave,
 * global shortcuts firing, captures starting and exiting.
 *
 * Off unless debug.trace is set, because these fire constantly.
 */
Singleton {
    id: root

    readonly property bool on: Config.get("debug.trace", false)

    function log(tag, message) {
        if (root.on)
            console.log(`[trace] ${tag}: ${message}`);
    }
}
