//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1
//@ pragma DefaultEnv QSG_RENDER_LOOP=basic
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
import qs.modules.lyrics
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
        WallColours.mode;
        Cutout.enabled;
        // Reads the binds now, which also brings an old binds file up to date.
        Binds.refresh();
        // Puts your chosen window blur in place.
        Decor.blur;
        // Keeps app themes in step with the shell's colours.
        AppTheme.palette;
        // Looks for updates a little later, then every six hours.
        Updates.automatic;
        // Lazy like the rest: nothing else asks for it, so a low battery would
        // never be noticed unless the service is loaded here.
        BatteryAlert.enabled;
        // Same: the lyrics follow whatever is playing without being looked at.
        Lyrics.enabled;
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

        // The four-finger-left path: open, to-do, closed.
        function sidebar(): string {
            Shell.sidebarSwipe();
            if (Shell.openPanel !== "control")
                return "closed";
            return Shell.sidebarTab === 1 ? "to-do" : "notifications";
        }
    }

    // Bottom of the stack, so everything else draws over it.
    Background {}
    WidgetLayer {}
    Bar {}
    Dashboard {}
    Control {}

    HotZones {}
    Toasts {}
    OsdOverlay {}
    ShotBar {}
    Session {}
    Lock {}
    Settings {}
    Spotlight {}
    LyricsPanel {}
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

        // What each screen's wallpaper is doing, when it is not doing it.
        function state(): string {
            const views = Wallpaper.views ?? {};
            const names = Object.keys(views);
            const head = `look: ${Config.get("wallpaper.look", "original")}`
                + ` · mono: ${Config.get("wallpaper.mono", false)}`
                + ` · shader allowed: ${Config.get("wallpaper.shader", true)}`;
            if (names.length === 0)
                return `${head}\n(no wallpaper layer has reported — is the shell drawing a wallpaper?)`;
            return [head, ...names.map(n => `${n}: ${views[n]}`)].join("\n");
        }
    }

    // `stratum ipc palette status` — what the shell knows about matugen. Here
    // rather than in WallColours: a handler inside a lazy singleton never registers.
    IpcHandler {
        target: "palette"

        function status(): string {
            // Undefined here means the service failed to load: see the log.
            if (WallColours.mode === undefined)
                return "WallColours did not load — see: stratum log";
            return [
                `mode:     ${WallColours.mode}`,
                `matugen:  ${WallColours.binary || "(none)"}`,
                `search:   ${WallColours.searched}`,
                `image:    ${WallColours.image || "(no wallpaper)"}`,
                `error:    ${WallColours.error || "(none)"}`,
                `colours:  ${JSON.stringify(Theme.generated?.color ?? {})}`
            ].join("\n");
        }

        function find(): string {
            WallColours.binary = "";
            WallColours.find();
            return "searching again — ask for status in a second";
        }

        function run(): string {
            WallColours.cache = ({});
            WallColours.refresh();
            return "running matugen — ask for status in a second";
        }
    }

    // An app's window brought to this workspace, or the app started: what an
    // "open app" key runs.
    IpcHandler {
        target: "apps"

        function open(name: string): void {
            Apps.open(name);
        }
    }

    // Modes and one-shot actions, for stratumctl and your own keybinds.
    IpcHandler {
        target: "do"

        function game(on: string): string {
            GameMode.setOn(on === "toggle" ? !GameMode.on : on === "on");
            return GameMode.on ? "game mode on" : "game mode off";
        }

        function dnd(on: string): string {
            if ((on === "toggle") || (on === "on") !== Notifs.dnd)
                Notifs.toggleDnd();
            return Notifs.dnd ? "do not disturb on" : "do not disturb off";
        }

        // A focus mode by id (dnd, sleep, work, personal, gaming), "off" to
        // leave whichever is on. Until turned off.
        function focus(mode: string): string {
            if (mode === "off")
                Focus.stop();
            else
                Focus.set(mode, "off");
            return Focus.on ? `focus ${Focus.current.name} ${Focus.untilLabel}` : "focus off";
        }

        function caffeine(on: string): string {
            if ((on === "toggle") || (on === "on") !== Toggles.caffeine)
                Toggles.toggleCaffeine();
            return Toggles.caffeine ? "keeping awake" : "sleeping as usual";
        }

        function screenshot(kind: string): void {
            if (kind === "screen")
                Screenshot.screen();
            else if (kind === "edit")
                Screenshot.annotate();
            else
                Screenshot.region();
        }

        function record(kind: string): void {
            if (kind === "region")
                Toggles.toggleRecordRegion();
            else
                Toggles.toggleRecording();
        }

        function profile(name: string): string {
            if (name.length > 0)
                Power.setProfile(name === "eco" ? "power-saver" : name);
            return Power.profile;
        }

        function update(): string {
            Updates.update();
            return Updates.count > 0 ? "updating" : "nothing to update — run: stratumctl check";
        }

        function check(): string {
            Updates.check();
            return "checking — stratumctl updates to see the result";
        }

        function updates(): string {
            return Updates.count === 0 ? `up to date (${Updates.version})`
                : Updates.waiting.map(c => `${c.hash}  ${c.title}`).join("\n");
        }
    }

    /*
     * The words of whatever is playing. `status` is the one to reach for when
     * nothing is appearing: it says whether there is a key, whether the track
     * was recognised, and which source answered.
     */
    IpcHandler {
        target: "lyrics"

        function status(): string {
            return Lyrics.report();
        }

        // Stores the Spicy Lyrics key, in a file of its own beside shell.json.
        function key(value: string): string {
            if (value.length === 0)
                return Lyrics.haveKey ? "a key is set" : "no key set";
            Lyrics.saveKey(value);
            return `saved to ${Lyrics.keyPath}`;
        }

        // Asks again for the track playing, ignoring what was cached.
        function refresh(): string {
            Lyrics.refresh(true);
            return "asking again";
        }

        /*
         * Four lines of placeholder, timed from here, for checking the view and
         * the offset without needing a track both sources know. "line" shows
         * what a source that only timed its lines looks like, which is most of
         * them; anything else shows the swept kind.
         */
        function sample(kind: string): string {
            Lyrics.sample(kind);
            return `showing four ${kind === "line" ? "line-timed" : "word-timed"} sample lines for the next twelve seconds`;
        }

        // Nudges the words earlier or later, in milliseconds, for good.
        function offset(ms: int): string {
            Config.set("lyrics.offset" + "Ms", ms);
            return `${ms}ms`;
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
