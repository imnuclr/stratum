//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme
import qs.services
import qs.modules.bar
import qs.modules.control
import qs.modules.dashboard
import qs.modules.hotzones

ShellRoot {
    id: root

    // Vendored faces. Doto carries every numeral in the shell; Geist carries text.
    FontLoader {
        source: Quickshell.shellPath("assets/fonts/Doto.ttf")
    }
    FontLoader {
        source: Quickshell.shellPath("assets/fonts/Geist.ttf")
    }

    Component.onCompleted: {
        // Touch the config singletons so a malformed JSON file reports at startup
        // rather than on first panel open.
        Config.ready;
        Theme.ready;
    }

    // Quickshell singletons are lazy, and a lazy singleton never registers its
    // IpcHandler. Declaring the handler here — in the always-loaded root —
    // registers the target at startup and loads Shell on the first call, instead
    // of force-loading singletons just to get IPC.
    IpcHandler {
        target: "panel"

        function toggle(name: string): void {
            Shell.toggle(name);
        }

        function open(name: string): void {
            Shell.open(name);
        }

        function close(): void {
            Shell.close();
        }

        function current(): string {
            return Shell.openPanel;
        }
    }

    Bar {}
    Dashboard {}
    Control {}
    HotZones {}
}
