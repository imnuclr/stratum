import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Type to find anything: an app, a file, a settings page, something the shell
 * can do, or the answer to a sum. Results come in groups, the best one first,
 * with a preview of whichever is chosen beside them.
 *
 * It takes the keyboard outright while open — it is reached by a key and used
 * by typing, so there is no window behind it that should still be getting keys.
 * Esc, a click outside, or the key again closes it.
 */
PanelWindow {
    id: root

    required property ShellScreen monitor

    readonly property bool open: Shell.openPanel === "launcher"
        && (Shell.openScreen.length === 0 ? monitor.name === Shell.fallbackScreen : Shell.openScreen === monitor.name)

    property string query: ""
    // Everything listed, group headers included, as { header } or a result.
    property var rows: []
    property int sel: -1

    readonly property var chosen: root.sel >= 0 && root.sel < root.rows.length ? root.rows[root.sel] : null

    readonly property int cardWidth: Math.min(860, monitor.width - 80)
    readonly property int cardHeight: Math.min(540, monitor.height - 120)

    screen: monitor
    color: "transparent"
    visible: root.open || card.opacity > 0
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
        input.text = Launcher.preset;
        Launcher.preset = "";
        root.rebuild();
        input.forceActiveFocus();
    }

    onQueryChanged: {
        Launcher.searchFiles(root.query);
        root.rebuild();
    }

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

    // Settings pages, found by what they hold as much as by their name.
    readonly property var pages: [
        { page: "wallpaper", words: "wallpaper background picture photo image" },
        { page: "appearance", words: "appearance theme dark light colour color accent font dots" },
        { page: "bar", words: "bar panel top edge column height width workspaces" },
        { page: "monitors", words: "monitors displays screens resolution" },
        { page: "widgets", words: "widgets desktop clock weather" },
        { page: "keybinds", words: "keybinds keyboard shortcuts keys hotkeys" },
        { page: "notifications", words: "notifications toasts do not disturb" },
        { page: "advanced", words: "advanced debug config files" }
    ]

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

    /*
     * Builds the list for what is typed. `keep` holds the choice where it is when
     * results arrive late (file search, recents), so the row under your thumb
     * does not jump while you are about to press Enter on it.
     */
    function rebuild(keep) {
        const q = root.query.trim();
        const before = keep ? root.chosen : null;
        const groups = [];

        if (q.length === 0) {
            groups.push(["frequent", Launcher.rankApps("", 8).map(e => root.appRow(e, "frequent"))]);
            if (Config.get("launcher.recent", true))
                groups.push(["recent files", Launcher.recent.slice(0, 6).map(p => root.fileRow(p, "recent files"))]);
        } else {
            const sum = Config.get("launcher.calc", true) ? Launcher.calc(q) : null;
            if (sum !== null) {
                groups.push(["calculator", [{
                    group: "calculator", title: String(sum), sub: `${q} =`, icon: "calc", kind: "calc",
                    hint: "copy the answer", act: () => Quickshell.execDetached(["wl-copy", String(sum)])
                }]]);
            }

            const apps = Launcher.rankApps(q, 8).map(e => root.appRow(e, "apps"));

            const pages = root.pages
                .map(p => ({ p: p, s: Math.max(Launcher.score(p.page, q), ...p.words.split(" ").map(w => Launcher.score(w, q) * 0.8)) }))
                .filter(x => x.s >= 40)
                .sort((a, b) => b.s - a.s)
                .slice(0, 4)
                .map(x => ({
                    group: "settings", title: x.p.page, sub: "settings", icon: "settings", kind: "settings", score: x.s,
                    hint: "open settings here",
                    act: () => {
                        Shell.settingsPage = x.p.page;
                        Shell.open("settings");
                    },
                    keep: true
                }));

            const acts = root.actions
                .map(a => ({ a: a, s: Math.max(Launcher.score(a.title, q), ...a.words.split(" ").map(w => Launcher.score(w, q) * 0.85)) }))
                .filter(x => x.s >= 40)
                .sort((a, b) => b.s - a.s)
                .slice(0, 4)
                .map(x => ({ group: "actions", title: x.a.title, sub: "stratum", icon: x.a.icon, kind: "action", score: x.s, hint: "do it", act: x.a.act, keep: x.a.keep }));

            const recent = !Config.get("launcher.recent", true) ? [] : Launcher.recent
                .filter(p => Launcher.score(p.slice(p.lastIndexOf("/") + 1), q) >= 40)
                .slice(0, 4);
            const found = Config.get("launcher.files", true) ? Launcher.files : [];
            const files = [...recent, ...found.filter(p => !recent.includes(p))]
                .slice(0, 8)
                .map(p => root.fileRow(p, "files"));

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

            groups.push(["apps", apps], ["actions", acts], ["settings", pages], ["files", files]);
            const engine = Config.get("launcher.engine", "duckduckgo");
            const engines = {
                duckduckgo: "https://duckduckgo.com/?q=",
                google: "https://www.google.com/search?q=",
                brave: "https://search.brave.com/search?q=",
                startpage: "https://www.startpage.com/do/search?q="
            };
            if (Config.get("launcher.web", true)) {
                groups.push(["web", [{
                    group: "web", title: `search the web for “${q}”`, sub: engine, icon: "globe", kind: "web",
                    hint: "open in your browser",
                    act: () => Quickshell.execDetached(["xdg-open", (engines[engine] ?? engines.duckduckgo) + encodeURIComponent(q)])
                }]]);
            }
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
    // closes the launcher.
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.open ? 0.35 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.sheetMs
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
        y: Math.round(root.height * 0.18) + (root.open ? 0 : -12)
        width: root.cardWidth
        height: root.cardHeight
        radius: Theme.rSheet
        color: Theme.panel
        border.width: 1
        border.color: Theme.lineHi
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.98

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.sheetMs
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.sheetMs
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.sheetMs
                easing.type: Easing.OutCubic
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
            height: 68

            Glyph {
                id: lens

                anchors.left: parent.left
                anchors.leftMargin: Theme.space(5)
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 24
                stroke: 2
                color: Theme.fgBright
            }

            TextInput {
                id: input

                anchors.left: lens.right
                anchors.leftMargin: Theme.space(3)
                anchors.right: escHint.left
                anchors.rightMargin: Theme.space(3)
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 24
                selectByMouse: true
                selectionColor: Theme.fg
                selectedTextColor: Theme.panel
                clip: true
                focus: root.open

                onTextChanged: root.query = text

                Keys.onEscapePressed: Shell.close()
                Keys.onUpPressed: root.move(-1)
                Keys.onDownPressed: root.move(1)
                Keys.onTabPressed: root.move(1)
                Keys.onBacktabPressed: root.move(-1)
                Keys.onPressed: event => {
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
                    text: "search apps, files, settings…"
                    color: Theme.fgFaint
                    font: input.font
                    renderType: Text.NativeRendering
                }
            }

            SectionLabel {
                id: escHint

                anchors.right: parent.right
                anchors.rightMargin: Theme.space(5)
                anchors.verticalCenter: parent.verticalCenter
                text: "esc"
                color: Theme.fgFaint
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
            anchors.topMargin: Theme.space(2)
            anchors.bottomMargin: Theme.space(2)
            width: Math.round(parent.width * 0.54)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: root.rows
            highlightMoveDuration: 0

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                readonly property bool picked: index === root.sel

                width: list.width
                height: modelData.header ? 30 : 46

                SectionLabel {
                    visible: row.modelData.header
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space(5)
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.space(1)
                    text: row.modelData.title
                    color: Theme.fgDim
                }

                Rectangle {
                    visible: !row.modelData.header
                    anchors.fill: parent
                    anchors.leftMargin: Theme.space(2)
                    anchors.rightMargin: Theme.space(2)
                    radius: Theme.rInner
                    color: row.picked ? Theme.surfaceTop : (rowHover.hovered ? Theme.surfaceHi : "transparent")

                    // The chosen row carries the one red the shell allows itself.
                    Rectangle {
                        visible: row.picked
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.dot
                        height: Theme.dot
                        radius: width / 2
                        color: Theme.accent
                    }

                    Item {
                        id: thumb

                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space(3)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28

                        Image {
                            id: pic

                            anchors.fill: parent
                            visible: status === Image.Ready
                            source: row.modelData.image ?? ""
                            sourceSize.width: 56
                            sourceSize.height: 56
                            fillMode: row.modelData.kind === "file" ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                            asynchronous: true
                            smooth: true
                        }

                        Glyph {
                            anchors.centerIn: parent
                            visible: !pic.visible
                            name: row.modelData.icon ?? "app"
                            size: 20
                            color: row.picked ? Theme.fg : Theme.fgBright
                        }
                    }

                    Text {
                        id: title

                        anchors.left: thumb.right
                        anchors.leftMargin: Theme.space(3)
                        anchors.right: sub.left
                        anchors.rightMargin: Theme.space(2)
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: row.modelData.title
                        color: Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: 15
                        font.weight: row.picked ? Font.Medium : Font.Normal
                        renderType: Text.NativeRendering
                    }

                    Text {
                        id: sub

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.space(3)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width * 0.4)
                        elide: Text.ElideLeft
                        text: row.modelData.sub ?? ""
                        color: Theme.fgFaint
                        font.family: Theme.fontUi
                        font.pixelSize: 12
                        renderType: Text.NativeRendering
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

            Text {
                anchors.centerIn: parent
                visible: root.rows.length === 0
                text: "nothing yet — keep typing"
                color: Theme.fgFaint
                font.family: Theme.fontUi
                font.pixelSize: 14
                renderType: Text.NativeRendering
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
            anchors.margins: Theme.space(5)

            readonly property var item: root.chosen
            readonly property bool photo: !!item && item.kind === "file" && (item.image ?? "").length > 0

            visible: !!item

            // A picture fills the pane; anything else gets its icon, centred.
            Rectangle {
                id: frame

                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: preview.photo ? parent.width : 112
                height: preview.photo ? Math.min(parent.height * 0.55, parent.width * 0.75) : 112
                radius: preview.photo ? Theme.rTile : 28
                color: Theme.surfaceHi
                clip: true

                Image {
                    id: big

                    anchors.fill: parent
                    anchors.margins: preview.photo ? 0 : 20
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
                    width: 60
                    height: 60
                    name: preview.item?.icon ?? "app"
                    color: Theme.fg
                }
            }

            Column {
                anchors.top: frame.bottom
                anchors.topMargin: Theme.space(4)
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: Theme.space(2)

                Text {
                    width: parent.width
                    horizontalAlignment: preview.photo ? Text.AlignLeft : Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: preview.item?.title ?? ""
                    color: Theme.fg
                    font.family: preview.item?.kind === "calc" ? Theme.fontDot : Theme.fontUi
                    font.pixelSize: preview.item?.kind === "calc" ? 40 : 20
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                Text {
                    width: parent.width
                    horizontalAlignment: preview.photo ? Text.AlignLeft : Text.AlignHCenter
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: preview.item?.kind === "file" ? (preview.item?.path ?? "") : (preview.item?.about || preview.item?.sub || "")
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }

                SectionLabel {
                    anchors.horizontalCenter: preview.photo ? undefined : parent.horizontalCenter
                    visible: (preview.item?.uses ?? 0) > 0
                    text: `opened ${preview.item?.uses ?? 0} ${(preview.item?.uses ?? 0) === 1 ? "time" : "times"}`
                    color: Theme.fgFaint
                }
            }

            // How to use it, pinned to the bottom of the pane.
            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.space(2)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 22
                    radius: 6
                    color: Theme.surfaceTop

                    Text {
                        anchors.centerIn: parent
                        text: "↵"
                        color: Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                    }
                }

                SectionLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: preview.item?.hint ?? ""
                    color: Theme.fgDim
                }
            }
        }
    }
}
