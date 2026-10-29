pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Path resolution with user precedence.
 *
 * Anything loaded dynamically — widgets, control-centre toggles, dashboard
 * columns — resolves through here, so a file dropped in ~/.config/stratum/user/
 * shadows the built-in at the same relative path without forking the repo.
 *
 * Note this only covers dynamically loaded files. Shadowing a core component
 * used declaratively (`Tile {}`) would need the user directory ahead of the
 * shell on QML's import path, which Quickshell doesn't expose; `resolve` is
 * deliberately scoped to the loader boundary instead of pretending otherwise.
 */
Singleton {
    id: root

    readonly property string config: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/stratum`
    readonly property string userDir: `${config}/user`
    readonly property string cache: `${Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache"}/stratum`

    // Relative paths the user has overridden, discovered at startup.
    property var overrides: ({})

    function resolve(relative) {
        return overrides[relative] ? `file://${userDir}/${relative}` : Quickshell.shellPath(relative);
    }

    function isOverridden(relative) {
        return overrides[relative] === true;
    }

    // `find` is cheap and runs once; re-run it from the settings app after the
    // user adds a file rather than watching the whole tree.
    function rescan() {
        scanner.running = true;
    }

    Component.onCompleted: rescan()

    Process {
        id: scanner

        command: ["find", root.userDir, "-type", "f", "-name", "*.qml", "-printf", "%P\n"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = {};
                for (const line of text.split("\n"))
                    if (line.length > 0)
                        found[line] = true;
                root.overrides = found;
            }
        }
    }
}
