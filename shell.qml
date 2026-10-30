//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=threaded
//@ pragma DefaultEnv QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme
import qs.services
import qs.modules
import qs.modules.background
import qs.modules.bar
import qs.modules.control
import qs.modules.dashboard
import qs.modules.hotzones
import qs.modules.launcher
import qs.modules.lock
import qs.modules.notifications
import qs.modules.osd
import qs.modules.widgets
import qs.modules.session
import qs.modules.settings

ShellRoot {
    id: root

    // Vendored faces. Doto carries every numeral in the shell; Geist carries text.
    FontLoader {
        source: Quickshell.shellPath("assets/fonts/Doto.ttf")
    }
    FontLoader {
        source: Quickshell.shellPath("assets/fonts/Geist.ttf")
    }
    FontLoader {
        source: Quickshell.shellPath("assets/fonts/Nunito.ttf")
    }

    Component.onCompleted: {
        // Touch the config singletons so a malformed JSON file reports at startup
        // rather than on first panel open.
        Config.ready;
        Theme.ready;
        // Lazy, so touched here: nothing else asks for it until a colour is wanted.
        Palette.mode;
        Cutout.enabled;
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

        // Open settings on a named page: wallpaper, appearance, notifications, advanced.
        function settings(page: string): void {
            if (page.length > 0)
                Shell.settingsPage = page;
            Shell.open("settings");
        }

        function close(): void {
            Shell.close();
        }

        function current(): string {
            return Shell.openPanel;
        }

        // Which service list the control centre has open, if any.
        function expand(which: string): void {
            Shell.expand(which);
        }

        function expanded(): string {
            return Shell.expandedChip;
        }
    }

    // Bottom of the stack, so everything else draws over it.
    Background {}
    WidgetLayer {}
    Bar {}
    Dashboard {}
    Control {}

    Notifications {}
    HotZones {}
    Toasts {}
    OsdOverlay {}
    Session {}
    Lock {}
    Settings {}
    Spotlight {}
    WallpaperMenus {}
    WallpaperPickers {}
    Shortcuts {}

    Freeze {}
    CutoutLayer {}

    /*
     * Settings, scriptably. Values are JSON, so `config set notifications.toastMs 8000`
     * and `config set debug.trace true` both mean what they look like.
     */
    IpcHandler {
        target: "config"

        function get(key: string): string {
            return JSON.stringify(Config.get(key, null));
        }

        function set(key: string, json: string): string {
            try {
                return Config.set(key, JSON.parse(json)) ? "ok" : `refused: ${Config.error}`;
            } catch (e) {
                return `not valid JSON: ${json}`;
            }
        }

        function unset(key: string): string {
            return Config.unset(key) ? "ok" : `refused: ${Config.error}`;
        }
    }

    /*
     * Wallpapers. A monitor name picks one display; empty means the desktop.
     */
    IpcHandler {
        target: "wallpaper"

        function set(path: string, monitor: string): void {
            Wallpaper.set(Wallpaper.expand(path), monitor);
        }

        function next(monitor: string): void {
            Wallpaper.cycle(1, monitor);
        }

        function prev(monitor: string): void {
            Wallpaper.cycle(-1, monitor);
        }

        function random(monitor: string): void {
            Wallpaper.random(monitor);
        }

        function current(monitor: string): string {
            return Wallpaper.forMonitor(monitor);
        }

        function list(): string {
            return Wallpaper.entries.join("\n");
        }

        function rescan(): void {
            Wallpaper.scan();
        }
    }

    IpcHandler {
        target: "theme"

        function dark(on: bool): void {
            Toggles.setDark(on);
        }

        function mode(): string {
            return Theme.dark ? "dark" : "light";
        }
    }

    /*
     * Popouts by name, for scripting and for testing them without a pointer —
     * they are hover-driven, so there is otherwise no way to put one on screen
     * from outside the shell.
     */
    IpcHandler {
        target: "popout"

        function at(name: string, monitor: string, along: int): void {
            // hold, because nothing is hovering it: the popout would otherwise be
            // dismissed by its own grace timer the moment it appeared.
            Popouts.hold = true;
            Popouts.showAtY(name, along, monitor.length > 0 ? monitor : Quickshell.screens[0].name);
        }

        function hide(): void {
            Popouts.hold = false;
            Popouts.release(Popouts.current);
            Popouts.current = "";
        }

        function current(): string {
            return Popouts.current;
        }
    }
}
