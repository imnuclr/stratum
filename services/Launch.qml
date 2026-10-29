pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Launches external tools, and knows which of them exist.
 *
 * A "settings" button that opens nothing is worse than no button, and these
 * helpers are not all installed on every machine, so callers bind visibility to
 * has(). One probe at startup covers the whole list rather than one process per
 * candidate.
 */
Singleton {
    id: root

    readonly property var candidates: ["pavucontrol", "blueman-manager", "overskride",
        "nm-connection-editor", "iwgtk", "helvum", "pwvucontrol", "xdg-open"]

    property var available: ({})

    function has(name) {
        return available[name] === true;
    }

    // First installed candidate wins, so callers can state a preference order.
    function firstOf(names) {
        return names.find(n => has(n)) ?? "";
    }

    function run(name, args) {
        if (!has(name))
            return false;
        launcher.command = [name, ...(args ?? [])];
        launcher.running = true;
        return true;
    }

    function runFirstOf(names) {
        const found = firstOf(names);
        return found.length > 0 && run(found);
    }

    Process {
        id: launcher
    }

    Process {
        id: probe

        running: true
        command: ["sh", "-c", root.candidates.map(c => `command -v ${c} >/dev/null && echo ${c}`).join("; ")]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.split("\n")) {
                    const name = line.trim();
                    if (name.length > 0)
                        found[name] = true;
                }
                root.available = found;
            }
        }
    }
}
