import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

/*
 * The widget canvas on every monitor, and the ways into edit mode: a key, the
 * control centre, and `qs -c stratum ipc call widgets edit`.
 */
Scope {
    Variants {
        model: Quickshell.screens

        WidgetCanvas {
            required property ShellScreen modelData

            monitor: modelData
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "widgetsEdit"
        onPressed: Widgets.editing = !Widgets.editing
    }

    IpcHandler {
        target: "widgets"

        function edit(): void {
            Widgets.editing = !Widgets.editing;
        }

        function reset(): void {
            for (const screen of Quickshell.screens)
                Widgets.reset(screen.name);
        }
    }
}
