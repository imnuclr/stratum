import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Type to find anything: an app, a file, a setting, an open window, something
 * the shell can do, or the answer to a sum. Results come in groups, the best one
 * first, with a preview of whichever is chosen beside them.
 *
 * Start with > to search one kind only: >app, >file, >set, >do, >win, >web,
 * >run, and = for a sum. A bare > lists them.
 *
 * It takes the keyboard outright while open — it is reached by a key and used
 * by typing. Esc, a click outside, or the key again closes it.
 */
PanelWindow {
    id: root

    required property ShellScreen monitor

    readonly property bool open: Shell.openPanel === "launcher"
        && (Shell.openScreen.length === 0 ? monitor.name === Shell.fallbackScreen : Shell.openScreen === monitor.name)

    property string query: ""
    // The > command chosen, shown as a chip in front of what is typed.
    property string mode: ""
    // Everything listed, group headers included, as { header } or a result.
    property var rows: []
    property int sel: -1
    // Open windows, read when the launcher opens, for >win.
    property var windows: []

    readonly property var chosen: root.sel >= 0 && root.sel < root.rows.length ? root.rows[root.sel] : null

    readonly property int cardWidth: Math.min(880, monitor.width - 80)
    readonly property int cardHeight: Math.min(560, monitor.height - 120)

    /*
     * Mapped the whole time, with no input region while closed, as the sheets
     * are. A surface that appears on open gets Hyprland's layer animation, and
     * on a full-screen surface that is the dimmed backdrop visibly sliding in
     * behind the card. Already mapped, only the shell's own fade is seen.
     */
    screen: monitor
    color: "transparent"
    visible: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "stratum-launcher"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }

    onOpenChanged: {
        if (!root.open)
            return;
        Launcher.loadRecent();
        clients.running = false;
        clients.running = true;
        root.mode = "";
        input.text = Launcher.preset;
        Launcher.preset = "";
        root.rebuild();
        input.forceActiveFocus();
    }

    // What follows a command, or the whole query when there is none.
    readonly property var parsed: {
        const raw = root.query;
        if (root.mode.length > 0)
            return { cmd: root.mode, rest: raw.trim(), picking: false };
        if (raw.startsWith("=") && raw.length > 1)
            return { cmd: "calc", rest: raw.slice(1).trim(), picking: false };
        const m = /^>(\w*)(\s+([\s\S]*))?$/.exec(raw);
        if (!m)
            return { cmd: "", rest: raw.trim(), picking: false };
        const hit = root.commands.find(c => c.key === m[1] || c.also.includes(m[1]));
        // Still choosing which command: typing ">ap" or a bare ">".
        if (!hit || m[2] === undefined)
            return { cmd: hit && m[2] !== undefined ? hit.key : "", rest: m[1], picking: true };
        return { cmd: hit.key, rest: (m[3] ?? "").trim(), picking: false };
    }

    onModeChanged: root.rebuild()

    onParsedChanged: {
        const p = root.parsed;
        Launcher.searchFiles(p.picking ? "" : (p.cmd === "" || p.cmd === "file" ? p.rest : ""));
        root.rebuild();
    }

    // The > commands, for searching one kind of thing.
    readonly property var commands: [
        { key: "app", also: ["apps", "a"], title: "apps", detail: "applications only", icon: "app" },
        { key: "file", also: ["files", "f"], title: "files", detail: "files and folders in your home", icon: "file" },
        { key: "set", also: ["settings", "s"], title: "settings", detail: "a setting, by name or what it does", icon: "settings" },
        { key: "do", also: ["action", "actions"], title: "actions", detail: "lock, screenshot, wallpaper…", icon: "bolt" },
        { key: "win", also: ["window", "windows", "w"], title: "windows", detail: "jump to an open window", icon: "sidebar" },
        { key: "web", also: ["g", "search"], title: "web", detail: "search the web", icon: "globe" },
        { key: "run", also: ["sh", "cmd", "$"], title: "run", detail: "run a command", icon: "terminal" },
        { key: "calc", also: ["c", "math"], title: "calculator", detail: "or start with =", icon: "calc" }
    ]

    Connections {
        target: Launcher

        function onFilesChanged() {
            if (root.open)
                root.rebuild(true);
        }

        function onRecentChanged() {
            if (root.open)
                root.rebuild(true);
        }
    }

    Process {
        id: clients

        command: ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text).filter(c => c.mapped !== false && (c.title || c.class));
                } catch (e) {
                    root.windows = [];
                }
                if (root.open && root.parsed.cmd === "win")
                    root.rebuild(true);
            }
        }
    }

    // Things the shell can do, as { title, icon, words, act }.
    readonly property var actions: [
        { title: "lock", icon: "lock", words: "lock screen", act: () => Quickshell.execDetached(["loginctl", "lock-session"]) },
        { title: "sleep", icon: "moon", words: "sleep suspend", act: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { title: "log out", icon: "link-off", words: "log out logout exit", act: () => Quickshell.execDetached(["hyprctl", "dispatch", "exit"]) },
        { title: "restart", icon: "scan", words: "restart reboot", act: () => Quickshell.execDetached(["systemctl", "reboot"]) },
        { title: "shut down", icon: "power", words: "shut down shutdown power off poweroff", act: () => Quickshell.execDetached(["systemctl", "poweroff"]) },
        { title: "screenshot a region", icon: "scan", words: "screenshot capture region snip", act: () => Screenshot.region() },
        { title: "screenshot the screen", icon: "scan", words: "screenshot capture screen", act: () => Screenshot.screen() },
        { title: "record the screen", icon: "record", words: "record video screen capture", act: () => Toggles.toggleRecording() },
        { title: "record a region", icon: "record", words: "record video region", act: () => Toggles.recordRegion() },
        { title: Theme.dark ? "switch to light mode" : "switch to dark mode", icon: "contrast", words: "dark light mode theme", act: () => Toggles.toggleDark() },
        { title: "next wallpaper", icon: "image", words: "next wallpaper background", act: () => Wallpaper.cycle(1, "") },
        { title: "random wallpaper", icon: "image", words: "random shuffle wallpaper background", act: () => Wallpaper.random("") },
        { title: "arrange widgets", icon: "app", words: "arrange edit widgets", act: () => Widgets.editing = true },
        { title: "control centre", icon: "settings", words: "control centre center quick settings", act: () => Shell.toggle("control"), keep: true },
        { title: "dashboard", icon: "app", words: "dashboard deck", act: () => Shell.toggle("dashboard"), keep: true },
        { title: "night light", icon: "sun", words: "night light warm blue filter", act: () => Toggles.toggleNight() },
        { title: "caffeine", icon: "coffee", words: "caffeine keep awake idle inhibit", act: () => Toggles.toggleCaffeine() }
    ]

    function iconFor(entry) {
        const name = entry?.icon ?? "";
        if (name.length === 0)
            return "";
        if (name.startsWith("/"))
            return `file://${name}`;
        return Quickshell.iconPath(name, true) ?? "";
    }

    function isImage(path) {
        return /\.(png|jpe?g|webp|gif|bmp|svg|avif)$/i.test(path);
    }

    function fileRow(path, group) {
        const slash = path.lastIndexOf("/");
        const home = Quickshell.env("HOME");
        const dir = path.slice(0, slash);
        return {
            group: group,
            title: path.slice(slash + 1),
            sub: dir.startsWith(home) ? `~${dir.slice(home.length)}` : dir,
            icon: root.isImage(path) ? "image" : (/\.[a-z0-9]{1,5}$/i.test(path) ? "file" : "folder"),
            image: root.isImage(path) ? `file://${path}` : "",
            kind: "file",
            path: path,
            hint: "open · ctrl ↵ shows it in its folder",
            act: () => Quickshell.execDetached(["xdg-open", path]),
            alt: () => Quickshell.execDetached(["xdg-open", dir])
        };
    }

    function appRow(entry, group) {
        return {
            group: group,
            title: entry.name,
            sub: entry.genericName || entry.comment || "application",
            icon: "app",
            image: root.iconFor(entry),
            kind: "app",
            about: entry.comment ?? "",
            uses: Launcher.counts[entry.id] ?? 0,
            hint: "open",
            act: () => {
                Launcher.launched(entry);
                entry.execute();
            }
        };
    }

    function windowRow(c, group) {
        const cls = String(c.class ?? "");
        return {
            group: group,
            title: c.title || cls,
            sub: `${cls} · workspace ${c.workspace?.name ?? "?"}`,
            icon: "sidebar",
            image: Quickshell.iconPath(cls.toLowerCase(), true) ?? "",
            kind: "window",
            about: `${cls} on workspace ${c.workspace?.name ?? "?"}`,
            hint: "go to it",
            act: () => Hypr.focusWindow(c.address)
        };
    }

    // Each kind of result for a query, so a command can ask for just one.
    function appsFor(q, n) {
        return Launcher.rankApps(q, n).map(e => root.appRow(e, "apps"));
    }

    function settingsFor(q, n) {
        return SettingsSearch.search(q, n)
            .filter(r => r.score >= 50)
            .map(r => ({
                group: "settings", title: r.title, sub: `settings · ${r.page}`, icon: "settings", kind: "settings",
                score: Math.min(95, r.score), hint: "open it in settings",
                act: () => {
                    Shell.settingsPage = r.page;
                    Shell.settingsFocus = r.title;
                    Shell.open("settings");
                },
                keep: true
            }));
    }

    function actionsFor(q, n) {
        return root.actions
            .map(a => ({ a: a, s: q.length === 0 ? 50 : Math.max(Launcher.score(a.title, q), ...a.words.split(" ").map(w => Launcher.score(w, q) * 0.85)) }))
            .filter(x => x.s >= 40)
            .sort((a, b) => b.s - a.s)
            .slice(0, n)
            .map(x => ({ group: "actions", title: x.a.title, sub: "stratum", icon: x.a.icon, kind: "action", score: x.s, hint: "do it", act: x.a.act, keep: x.a.keep }));
    }

    function filesFor(q, n) {
        const recent = !Config.get("launcher.recent", true) ? [] : Launcher.recent
            .filter(p => q.length === 0 || Launcher.score(p.slice(p.lastIndexOf("/") + 1), q) >= 40)
            .slice(0, 4);
        const found = Config.get("launcher.files", true) ? Launcher.files : [];
        return [...recent, ...found.filter(p => !recent.includes(p))]
            .slice(0, n)
            .map(p => root.fileRow(p, "files"));
    }

    function windowsFor(q, n) {
        return root.windows
            .map(c => ({ c: c, s: q.length === 0 ? 50 : Math.max(Launcher.score(c.title, q), Launcher.score(c.class, q)) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s)
            .slice(0, n)
            .map(x => root.windowRow(x.c, "windows"));
    }

    function webFor(q) {
        if (q.length === 0)
            return [];
        const engine = Config.get("launcher.engine", "duckduckgo");
        const engines = {
            duckduckgo: "https://duckduckgo.com/?q=",
            google: "https://www.google.com/search?q=",
            brave: "https://search.brave.com/search?q=",
            startpage: "https://www.startpage.com/do/search?q="
        };
        return [{
            group: "web", title: `search the web for “${q}”`, sub: engine, icon: "globe", kind: "web",
            hint: "open in your browser",
            act: () => Quickshell.execDetached(["xdg-open", (engines[engine] ?? engines.duckduckgo) + encodeURIComponent(q)])
        }];
    }

    function calcFor(q) {
        const sum = Launcher.calc(q);
        if (sum === null)
            return [];
        return [{
            group: "calculator", title: String(sum), sub: `${q} =`, icon: "calc", kind: "calc",
            hint: "copy the answer", act: () => Quickshell.execDetached(["wl-copy", String(sum)])
        }];
    }

    function runFor(q) {
        if (q.length === 0)
            return [];
        return [{
            group: "run", title: q, sub: "run this command", icon: "terminal", kind: "run",
            about: "Runs in the background, detached from the shell.",
            hint: "run it", act: () => Quickshell.execDetached(["sh", "-c", q])
        }];
    }

    function commandRows(prefix) {
        return root.commands
            .filter(c => prefix.length === 0 || c.key.startsWith(prefix) || c.also.some(a => a.startsWith(prefix)))
            .map(c => ({
                group: "search one kind", title: c.key === "calc" ? "= or >calc" : `>${c.key}`, sub: c.detail, icon: c.icon,
                kind: "command", about: `Type >${c.key} and then what to look for, to search ${c.title} only.`,
                hint: "use it", keep: true,
                act: () => {
                    input.text = `>${c.key} `;
                    input.cursorPosition = input.text.length;
                }
            }));
    }

    /*
     * Builds the list for what is typed. `keep` holds the choice where it is when
     * results arrive late (file search, recents), so the row under your thumb
     * does not jump while you are about to press Enter on it.
     */
    function rebuild(keep) {
        const p = root.parsed;
        const q = p.rest;
        const before = keep ? root.chosen : null;
        const groups = [];

        if (p.picking) {
            groups.push(["search one kind", root.commandRows(q)]);
        } else if (p.cmd === "app") {
            groups.push(["apps", root.appsFor(q, 30)]);
        } else if (p.cmd === "file") {
            groups.push(["files", root.filesFor(q, 24)]);
        } else if (p.cmd === "set") {
            groups.push(["settings", q.length > 0 ? root.settingsFor(q, 20) : []]);
        } else if (p.cmd === "do") {
            groups.push(["actions", root.actionsFor(q, 30)]);
        } else if (p.cmd === "win") {
            groups.push(["windows", root.windowsFor(q, 30)]);
        } else if (p.cmd === "web") {
            groups.push(["web", root.webFor(q)]);
        } else if (p.cmd === "run") {
            groups.push(["run", root.runFor(q)]);
        } else if (p.cmd === "calc") {
            groups.push(["calculator", root.calcFor(q)]);
        } else if (q.length === 0) {
            // Only what you have actually used: a list of every app A to Z is
            // not a suggestion.
            const used = Launcher.rankApps("", 8).filter(e => (Launcher.counts[e.id] ?? 0) > 0);
            groups.push(["frequent", used.map(e => root.appRow(e, "frequent"))]);
            if (Config.get("launcher.recent", true))
                groups.push(["recent files", Launcher.recent.slice(0, 5).map(f => root.fileRow(f, "recent files"))]);
        } else {
            if (Config.get("launcher.calc", true))
                groups.push(["calculator", root.calcFor(q)]);

            const apps = root.appsFor(q, 8);
            const pages = root.settingsFor(q, 4);
            const acts = root.actionsFor(q, 4);
            const wins = root.windowsFor(q, 3).filter(w => Launcher.score(w.title, q) >= 60);

            // The best of everything leads, whatever kind it is.
            const best = [
                apps.length > 0 ? { row: apps[0], s: Launcher.appScore(Launcher.rankApps(q, 1)[0], q) } : null,
                pages.length > 0 ? { row: pages[0], s: pages[0].score } : null,
                acts.length > 0 ? { row: acts[0], s: acts[0].score } : null
            ].filter(x => x !== null).sort((a, b) => b.s - a.s)[0];

            if (best) {
                groups.push(["top hit", [Object.assign({}, best.row, { group: "top hit" })]]);
                for (const list of [apps, pages, acts]) {
                    const i = list.indexOf(best.row);
                    if (i >= 0)
                        list.splice(i, 1);
                }
            }

            groups.push(["apps", apps], ["windows", wins], ["actions", acts], ["settings", pages], ["files", root.filesFor(q, 8)]);
            if (Config.get("launcher.web", true))
                groups.push(["web", root.webFor(q)]);
        }

        const rows = [];
        for (const [name, list] of groups) {
            if (list.length === 0)
                continue;
            rows.push({ header: true, title: name });
            rows.push(...list);
        }
        root.rows = rows;

        let at = -1;
        if (before)
            at = rows.findIndex(r => !r.header && r.title === before.title && r.group === before.group);
        root.sel = at >= 0 ? at : rows.findIndex(r => !r.header);
        if (!keep)
            list.positionViewAtBeginning();
    }

    function move(step) {
        if (root.rows.length === 0)
            return;
        let i = root.sel;
        for (let n = 0; n < root.rows.length; n++) {
            i = (i + step + root.rows.length) % root.rows.length;
            if (!root.rows[i].header) {
                root.sel = i;
                list.positionViewAtIndex(i, ListView.Contain);
                if (i === root.rows.findIndex(r => !r.header))
                    list.positionViewAtBeginning();
                return;
            }
        }
    }

    function activate(row, alt) {
        if (!row || row.header)
            return;
        const act = alt && row.alt ? row.alt : row.act;
        if (row.keep) {
            act();
            return;
        }
        Shell.close();
        // Once the launcher is off screen, so a screenshot does not catch it and
        // the app that opens is handed the keyboard rather than fighting for it.
        pending.act = act;
        pending.restart();
    }

    Timer {
        id: pending

        property var act: null

        interval: Theme.sheetMs + 40
        onTriggered: {
            if (act)
                act();
            act = null;
        }
    }


    // Dims the desktop so the card is the only thing to look at; a click on it
    // closes the launcher. Fades only: nothing about it moves.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? 0.28 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.sheetMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.open
            onClicked: Shell.close()
        }
    }

    Rectangle {
        id: card

        x: Math.round((root.width - root.cardWidth) / 2)
        y: Math.round(root.height * 0.16)
        width: root.cardWidth
        height: root.cardHeight
        radius: Theme.rSheet
        color: Theme.panel
        border.width: 1
        border.color: Theme.lineHi
        opacity: root.open ? 1 : 0
        // Grows very slightly into place rather than travelling.
        scale: root.open ? 1 : 0.985
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.sheetMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.sheetMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        // Clicks on the card stay on the card.
        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: bar

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 72

            Glyph {
                id: lens

                anchors.left: parent.left
                anchors.leftMargin: Theme.space(6)
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 22
                stroke: 2
                color: Theme.fgDim
            }

            // The command in use, as a chip before the text.
            Rectangle {
                id: chip

                readonly property var command: root.commands.find(c => c.key === root.mode) ?? null

                anchors.left: lens.right
                anchors.leftMargin: Theme.space(3)
                anchors.verticalCenter: parent.verticalCenter
                visible: !!command
                width: visible ? chipText.implicitWidth + Theme.space(3) * 2 : 0
                height: 28
                radius: 14
                color: Theme.fg

                Text {
                    id: chipText

                    anchors.centerIn: parent
                    text: chip.command?.title ?? ""
                    color: Theme.bg
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }
            }

            TextInput {
                id: input

                anchors.left: chip.visible ? chip.right : lens.right
                anchors.leftMargin: Theme.space(3)
                anchors.right: info.left
                anchors.rightMargin: Theme.space(3)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 22
                selectByMouse: true
                selectionColor: Theme.fg
                selectedTextColor: Theme.panel
                clip: true
                focus: root.open

                // A finished command (">app ") becomes the chip, and only what
                // follows it stays in the field.
                onTextChanged: {
                    const m = /^>(\w+)\s([\s\S]*)$/.exec(text);
                    if (root.mode.length === 0 && m) {
                        const hit = root.commands.find(c => c.key === m[1] || c.also.includes(m[1]));
                        if (hit) {
                            root.mode = hit.key;
                            text = m[2];
                            return;
                        }
                    }
                    root.query = text;
                }

                Keys.onEscapePressed: Shell.close()
                Keys.onUpPressed: root.move(-1)
                Keys.onDownPressed: root.move(1)
                Keys.onTabPressed: {
                    // Tab completes a command being picked; otherwise moves down.
                    if (root.parsed.picking && root.chosen?.kind === "command")
                        root.activate(root.chosen, false);
                    else
                        root.move(1);
                }
                Keys.onBacktabPressed: root.move(-1)
                Keys.onPressed: event => {
                    // Backspace with nothing typed takes the command chip off.
                    if (event.key === Qt.Key_Backspace && root.mode.length > 0 && input.text.length === 0) {
                        root.mode = "";
                        event.accepted = true;
                        return;
                    }
                    if (event.modifiers & Qt.ControlModifier) {
                        if (event.key === Qt.Key_N || event.key === Qt.Key_J) {
                            root.move(1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_P || event.key === Qt.Key_K) {
                            root.move(-1);
                            event.accepted = true;
                        }
                    }
                }
                Keys.onReturnPressed: event => root.activate(root.chosen, event.modifiers & Qt.ControlModifier)
                Keys.onEnterPressed: event => root.activate(root.chosen, event.modifiers & Qt.ControlModifier)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text.length === 0
                    text: chip.visible ? `Search ${chip.command?.title ?? ""}…` : "Search apps, files, settings…   or type >"
                    color: Theme.fgFaint
                    font: input.font
                    renderType: Text.NativeRendering
                }
            }

            // The keys, for whoever wants them, out of the way until asked.
            Rectangle {
                id: info

                anchors.right: escHint.left
                anchors.rightMargin: Theme.space(2)
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 11
                color: infoHover.hovered ? Theme.surfaceTop : Theme.surfaceHi
                border.width: 1
                border.color: Theme.line

                Text {
                    anchors.centerIn: parent
                    text: "i"
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                HoverHandler {
                    id: infoHover
                }
            }

            Rectangle {
                id: escHint

                anchors.right: parent.right
                anchors.rightMargin: Theme.space(5)
                anchors.verticalCenter: parent.verticalCenter
                width: escText.implicitWidth + Theme.space(2) * 2
                height: 22
                radius: 6
                color: Theme.surfaceHi
                border.width: 1
                border.color: Theme.line

                Text {
                    id: escText

                    anchors.centerIn: parent
                    text: "esc"
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Theme.line
            }
        }

        ListView {
            id: list

            anchors.top: bar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.topMargin: Theme.space(1)
            width: Math.round(parent.width * 0.56)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows
            highlightMoveDuration: 0
            bottomMargin: Theme.space(2)

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                readonly property bool header: !!row.modelData.header
                readonly property bool picked: index === root.sel

                width: list.width
                height: row.header ? 34 : 54

                SectionLabel {
                    visible: row.header
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space(5)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: row.header ? row.modelData.title : ""
                    color: Theme.fgFaint
                }

                Rectangle {
                    visible: !row.header
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space(2)
                    anchors.rightMargin: Theme.space(2)
                    radius: Theme.rInner
                    color: row.picked ? Theme.surfaceTop : (rowHover.hovered ? Theme.surfaceHi : "transparent")

                    // The chosen row carries the one red the shell allows itself.
                    Rectangle {
                        visible: row.picked
                        anchors.left: parent.left
                        anchors.leftMargin: 5
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: 18
                        radius: 1.5
                        color: Theme.accent
                    }

                    Rectangle {
                        id: thumb

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space(3)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        radius: 10
                        color: pic.visible ? "transparent" : Theme.surfaceHi
                        clip: true

                        Image {
                            id: pic

                            anchors.fill: parent
                            anchors.margins: row.modelData.kind === "file" ? 0 : 2
                            visible: status === Image.Ready
                            source: row.header ? "" : (row.modelData.image ?? "")
                            sourceSize.width: 72
                            sourceSize.height: 72
                            fillMode: row.modelData.kind === "file" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }

                        Glyph {
                            anchors.centerIn: parent
                            visible: !pic.visible
                            name: row.modelData.icon ?? "app"
                            size: 18
                            color: row.picked ? Theme.fg : Theme.fgBright
                        }
                    }

                    Column {
                        anchors.left: thumb.right
                        anchors.leftMargin: Theme.space(3)
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space(3)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: row.header ? "" : row.modelData.title
                            color: Theme.fg
                            font.family: row.modelData.kind === "command" ? Theme.fontMono : Theme.fontUi
                            font.pixelSize: 15
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }

                        Text {
                            width: parent.width
                            visible: text.length > 0
                            elide: row.modelData.kind === "file" ? Text.ElideMiddle : Text.ElideRight
                            text: row.header ? "" : (row.modelData.sub ?? "")
                            color: Theme.fgDim
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                        }
                    }

                    HoverHandler {
                        id: rowHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            root.sel = row.index;
                            root.activate(row.modelData, false);
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.space(2)
                visible: root.rows.length === 0

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "search"
                    size: 28
                    color: Theme.fgFaint
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.query.length === 0 ? "Start typing" : "Nothing found"
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                }
            }
        }

        Rectangle {
            id: divider

            anchors.top: bar.bottom
            anchors.bottom: parent.bottom
            anchors.left: list.right
            width: 1
            color: Theme.line
        }

        // What the chosen result is, large enough to be sure before pressing Enter.
        Item {
            id: preview

            anchors.top: bar.bottom
            anchors.bottom: parent.bottom
            anchors.left: divider.right
            anchors.right: parent.right
            anchors.margins: Theme.space(6)

            readonly property var item: root.chosen
            readonly property bool photo: !!item && item.kind === "file" && (item.image ?? "").length > 0

            visible: !!item && !item.header

            Column {
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -Theme.space(2)
                width: parent.width
                spacing: Theme.space(4)

                // A picture fills the width; anything else gets its icon on a tile.
                Rectangle {
                    id: frame

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: preview.photo ? parent.width : 104
                    height: preview.photo ? Math.min(preview.height * 0.55, parent.width * 0.75) : 104
                    radius: preview.photo ? Theme.rTile : 26
                    color: Theme.surfaceHi
                    border.width: 1
                    border.color: Theme.line
                    clip: true

                    Image {
                        id: big

                        anchors.fill: parent
                        anchors.margins: preview.photo ? 0 : 18
                        visible: status === Image.Ready
                        source: preview.item?.image ?? ""
                        sourceSize.width: preview.photo ? 640 : 160
                        sourceSize.height: preview.photo ? 480 : 160
                        fillMode: preview.photo ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                    }

                    DotIcon {
                        anchors.centerIn: parent
                        visible: !big.visible
                        width: 56
                        height: 56
                        name: preview.item?.icon ?? "app"
                        color: Theme.fg
                    }
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: preview.item?.title ?? ""
                    color: Theme.fg
                    font.family: preview.item?.kind === "calc" ? Theme.fontDot : Theme.fontUi
                    font.pixelSize: preview.item?.kind === "calc" ? 44 : 20
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: preview.item?.kind === "file" ? Text.WrapAnywhere : Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: preview.item?.kind === "file" ? (preview.item?.path ?? "") : (preview.item?.about || preview.item?.sub || "")
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }

                SectionLabel {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: (preview.item?.uses ?? 0) > 0
                    text: `opened ${preview.item?.uses ?? 0} ${(preview.item?.uses ?? 0) === 1 ? "time" : "times"}`
                    color: Theme.fgFaint
                }
            }
        }

        Rectangle {
            id: keysCard

            anchors.top: bar.bottom
            anchors.topMargin: -Theme.space(2)
            anchors.right: parent.right
            anchors.rightMargin: Theme.space(5)
            width: keysColumn.implicitWidth + Theme.space(4) * 2
            height: keysColumn.implicitHeight + Theme.space(3) * 2
            radius: Theme.rInner
            color: Theme.surface
            border.width: 1
            border.color: Theme.lineHi
            z: 20
            opacity: infoHover.hovered ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

            Column {
                id: keysColumn

                anchors.centerIn: parent
                spacing: Theme.space(2)

                Repeater {
                    model: [
                        ["↵", "open"],
                        ["ctrl ↵", "show a file in its folder"],
                        ["↑ ↓", "move"],
                        ["tab", "finish a > command"],
                        [">", "search one kind: app, file, set, do, win, web, run"],
                        ["=", "calculate"]
                    ]

                    Row {
                        required property var modelData

                        spacing: Theme.space(3)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 52
                            height: 22
                            radius: 6
                            color: Theme.surfaceHi
                            border.width: 1
                            border.color: Theme.line

                            Text {
                                anchors.centerIn: parent
                                text: modelData[0]
                                color: Theme.fgBright
                                font.family: Theme.fontUi
                                font.pixelSize: 11
                                renderType: Text.NativeRendering
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData[1]
                            color: Theme.fgDim
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
    }
}
