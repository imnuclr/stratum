import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

/*
 * The launcher: one per screen, shown on whichever the keybind was pressed on.
 */
Scope {
    Variants {
        model: Quickshell.screens

        SpotlightWindow {
            required property ShellScreen modelData

            monitor: modelData
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "launcher"
        onPressed: Shell.toggle("launcher")
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Shell.toggle("launcher");
        }

        // Opens with something already typed: `launcher search firefox`.
        function search(query: string): void {
            Launcher.preset = query;
            Shell.open("launcher");
        }
    }
}
