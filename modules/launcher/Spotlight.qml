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

    /*
     * Fires on the press, or on a release with no press before it. Super on
     * its own is a release bind, so that it waits to see whether another key
     * follows, and Hyprland hands a release bind's shortcut only the release:
     * listening for the press alone, tapping Super did nothing.
     */
    GlobalShortcut {
        id: launcherKey

        property bool pressed: false

        appid: "stratum"
        name: "launcher"
        onPressed: {
            launcherKey.pressed = true;
            Shell.toggle("launcher");
        }
        onReleased: {
            if (!launcherKey.pressed)
                Shell.toggle("launcher");
            launcherKey.pressed = false;
        }
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
