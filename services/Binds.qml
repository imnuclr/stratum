pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*
 * Every key binding Hyprland has, and the shell's own.
 *
 * All of them are read from `hyprctl binds -j` so the keyboard in settings can
 * show what each key does wherever it was bound. The shell's own — keys pointed
 * at its global shortcuts — are kept in shell.json (`keybinds.own`) and written
 * out as ~/.config/hypr/stratum-binds.lua (or .conf, for a plain-text config),
 * the file your config already loads; Hyprland is then reloaded. Only that file
 * is ever written: binds from the rest of your config are shown, never edited.
 */
Singleton {
    id: root

    // Every bind, as { mods, mask, key, k, dispatcher, arg, description, stratum }.
    property var all: []
    property bool lua: true
    property string error: ""

    readonly property string hyprDir: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/hypr`

    // What the shell can be asked to do from a key.
    readonly property var actions: [
        { name: "launcher", label: "launcher" },
        { name: "lock", label: "lock the screen" },
        { name: "session", label: "session menu" },
        { name: "control", label: "control centre" },
        { name: "deck", label: "dashboard" },
        { name: "widgetsEdit", label: "arrange widgets" },
        { name: "screenshotRegion", label: "screenshot a region" },
        { name: "screenshot", label: "screenshot the screen" },
        { name: "screenshotEdit", label: "screenshot and annotate" },
        { name: "recordRegion", label: "record a region" },
        { name: "record", label: "record the screen" },
        { name: "mediaToggle", label: "play / pause" },
        { name: "mediaNext", label: "next track" },
        { name: "mediaPrev", label: "previous track" },
        { name: "volumeUp", label: "volume up" },
        { name: "volumeDown", label: "volume down" },
        { name: "volumeMute", label: "mute" },
        { name: "micMute", label: "mute the mic" },
        { name: "brightnessUp", label: "brightness up" },
        { name: "brightnessDown", label: "brightness down" }
    ]

    // The binds the shell ships with, until any are changed.
    readonly property var defaults: [
        { mods: [], key: "XF86AudioPlay", action: "mediaToggle" },
        { mods: [], key: "XF86AudioPause", action: "mediaToggle" },
        { mods: [], key: "XF86AudioNext", action: "mediaNext" },
        { mods: [], key: "XF86AudioPrev", action: "mediaPrev" },
        { mods: [], key: "XF86AudioRaiseVolume", action: "volumeUp" },
        { mods: [], key: "XF86AudioLowerVolume", action: "volumeDown" },
        { mods: [], key: "XF86AudioMute", action: "volumeMute" },
        { mods: [], key: "XF86AudioMicMute", action: "micMute" },
        { mods: [], key: "XF86MonBrightnessUp", action: "brightnessUp" },
        { mods: [], key: "XF86MonBrightnessDown", action: "brightnessDown" },
        { mods: [], key: "Print", action: "screenshotRegion" },
        { mods: ["SUPER", "SHIFT"], key: "S", action: "screenshotRegion" },
        { mods: ["SUPER"], key: "Print", action: "screenshot" },
        { mods: ["CTRL"], key: "Print", action: "screenshotEdit" },
        { mods: ["SUPER"], key: "L", action: "lock" },
        { mods: ["SUPER"], key: "SPACE", action: "launcher" },
        { mods: ["ALT"], key: "Print", action: "recordRegion" },
        { mods: ["SUPER", "ALT"], key: "Print", action: "record" },
        { mods: ["SUPER", "SHIFT"], key: "W", action: "widgetsEdit" }
    ]

    readonly property var own: Config.get("keybinds.own", null) ?? root.defaults

    readonly property var modBits: [["SHIFT", 1], ["CTRL", 4], ["ALT", 8], ["SUPER", 64]]
    // Caps and Num Lock are modifiers to Hyprland, but nobody means them.
    readonly property int ignoredBits: 2 | 16

    /*
     * What each bind in your Lua config does, in words, keyed "mask:key".
     *
     * Hyprland only reports a Lua bind as `__lua` and a number, so the config
     * itself is read: every hl.bind("COMBO", ...) call, with a comment beside or
     * above it preferred, and otherwise the dispatcher inside explained.
     */
    property var luaWords: ({})

    // Dispatchers in words. Keys have underscores dropped, so the Lua names
    // (exec_cmd, kill_active) land on the same entries as the conf ones.
    readonly property var dispatchers: ({
        "exec": a => root.runWords(a),
        "execcmd": a => root.runWords(a),
        "execr": a => root.runWords(a),
        "killactive": () => "close the window",
        "close": () => "close the window",
        "forcekillactive": () => "force close the window",
        "closewindow": () => "close the window",
        "kill": () => "force close the window",
        "float": () => "float the window",
        "tile": () => "tile the window",
        "togglefloat": () => "float or tile the window",
        "resize": a => `resize the window${a ? ` (${a})` : ""}`,
        "move": a => `move the window${a ? ` ${root.dirWords(a)}` : ""}`,
        "focus": a => `focus ${root.dirWords(a)}`,
        "killwindow": () => "force close the window",
        "exit": () => "quit Hyprland",
        "togglefloating": () => "float or tile the window",
        "setfloating": () => "float the window",
        "settiled": () => "tile the window",
        "fullscreen": a => /^1|maximi/.test(a) ? "maximise the window" : "make the window fullscreen",
        "fullscreenstate": () => "fullscreen the window",
        "pseudo": () => "pseudotile the window",
        "pin": () => "pin the window to every workspace",
        "togglesplit": () => "flip the split",
        "swapsplit": () => "swap the split",
        "centerwindow": () => "centre the window",
        "workspace": a => root.workspaceWords("go to", a),
        "movetoworkspace": a => root.workspaceWords("move the window to", a),
        "movetoworkspacesilent": a => root.workspaceWords("send the window to", a),
        "togglespecialworkspace": a => a ? `show or hide the ${a} scratchpad` : "show or hide the scratchpad",
        "movefocus": a => `focus the window ${root.dirWords(a)}`,
        "movewindow": a => `move the window ${root.dirWords(a)}`,
        "swapwindow": a => `swap with the window ${root.dirWords(a)}`,
        "resizeactive": a => `resize the window (${a})`,
        "focusmonitor": a => `focus monitor ${a}`,
        "movecurrentworkspacetomonitor": a => `move this workspace to monitor ${a}`,
        "cyclenext": a => /prev/.test(a) ? "focus the previous window" : "focus the next window",
        "focusurgentorlast": () => "focus the last window",
        "togglegroup": () => "group or ungroup windows",
        "changegroupactive": a => /b/.test(a) ? "previous window in the group" : "next window in the group",
        "submap": a => a === "reset" ? "leave the submap" : `enter the ${a} submap`,
        "dpms": a => `screen power ${a || "toggle"}`,
        "layoutmsg": a => `layout: ${a}`,
        "global": a => a.startsWith("stratum:") ? root.actionLabel(a.slice(8)) : `shortcut ${a}`,
        "pass": a => `pass the key to ${a}`,
        "sendshortcut": a => `send ${a}`
    })

    function dirWords(a) {
        return ({ l: "to the left", r: "to the right", u: "above", d: "below",
            left: "to the left", right: "to the right", up: "above", down: "below" })[String(a).toLowerCase()] ?? a;
    }

    function workspaceWords(verb, a) {
        a = String(a);
        if (/^\d+$/.test(a))
            return `${verb} workspace ${a}`;
        if (/^[er]\+1$|^\+1$|^m\+1$/.test(a))
            return `${verb} the next workspace`;
        if (/^[er]-1$|^-1$|^m-1$/.test(a))
            return `${verb} the previous workspace`;
        if (a.startsWith("special"))
            return `${verb} the scratchpad`;
        if (a === "previous")
            return `${verb} the last workspace`;
        return `${verb} workspace ${a}`;
    }

    // A command line as what it opens: "kitty" reads as "open kitty".
    function runWords(cmd) {
        cmd = String(cmd).trim().replace(/^\[[^\]]*\]\s*/, "");
        if (cmd.length === 0)
            return "run a command";
        const words = cmd.split(/\s+/);
        let i = 0;
        while (i < words.length - 1 && (/^(uwsm|app2unit|setsid|env|exec|nohup|systemd-run)$/.test(words[i]) || /^-/.test(words[i]) || /=/.test(words[i]) || words[i] === "app" || words[i] === "--"))
            i++;
        const prog = words[i].split("/").pop();
        const rest = words.slice(i + 1).join(" ");
        const known = {
            "wpctl": "change the volume", "pamixer": "change the volume", "pactl": "change the volume",
            "brightnessctl": "change the brightness", "playerctl": "control media",
            "grim": "take a screenshot", "hyprshot": "take a screenshot", "grimblast": "take a screenshot",
            "hyprlock": "lock the screen", "swaylock": "lock the screen", "loginctl": rest.includes("lock") ? "lock the screen" : "session",
            "hyprpicker": "pick a colour", "cliphist": "clipboard history", "qs": "a Stratum command", "quickshell": "a Stratum command",
            "systemctl": rest.includes("suspend") ? "sleep" : rest.includes("poweroff") ? "shut down" : rest.includes("reboot") ? "restart" : "system command",
            "pkill": `stop ${rest.split(" ").pop()}`, "killall": `stop ${rest.split(" ").pop()}`
        };
        if (known[prog])
            return known[prog];
        if (/^(rofi|wofi|fuzzel|tofi|anyrun|walker|bemenu|dmenu)/.test(prog))
            return `open ${prog} (launcher)`;
        return `open ${prog}`;
    }

    function explain(dispatcher, arg) {
        const d = String(dispatcher).toLowerCase().replace(/_/g, "");
        const f = root.dispatchers[d];
        return f ? f(String(arg ?? "").trim()) : `${dispatcher} ${arg ?? ""}`.trim();
    }

    // A dispatcher called with a table, as in hl.dsp.focus({ workspace = 1 }).
    function explainTable(name, text, value) {
        const t = {};
        const field = /(\w+)\s*=\s*("[^"]*"|'[^']*'|[^,}]+)/g;
        for (let f = field.exec(text); f !== null; f = field.exec(text))
            t[f[1]] = value(f[2]);
        const n = name.toLowerCase();
        if (t.workspace !== undefined)
            return root.workspaceWords(/move|send/.test(n) ? (/silent/.test(n) || t.follow === "false" ? "send the window to" : "move the window to") : "go to", t.workspace);
        if (t.direction !== undefined)
            return /swap/.test(n) ? `swap with the window ${root.dirWords(t.direction)}`
                : /move/.test(n) ? `move the window ${root.dirWords(t.direction)}`
                : `focus the window ${root.dirWords(t.direction)}`;
        if (t.monitor !== undefined)
            return /move/.test(n) ? `move to monitor ${t.monitor}` : `focus monitor ${t.monitor}`;
        const first = Object.keys(t).map(k => t[k])[0] ?? "";
        return root.explain(n.split(".").pop(), first);
    }

    // What a bind does, for the keybinds page.
    function describe(b) {
        if (b.stratum)
            return root.actionLabel(b.arg.slice("stratum:".length));
        if (b.description.length > 0)
            return b.description;
        if (b.dispatcher === "__lua")
            return root.luaWords[`${b.mask}:${b.k}`] ?? "a Lua function in your config";
        return root.explain(b.dispatcher, b.arg);
    }

    /*
     * Reads hl.bind calls out of Lua source. Not a Lua parser: it finds each
     * call, takes its first argument as the combination and balances brackets
     * to find where the rest ends, which is enough for how binds are written.
     */
    function parseLua(src) {
        const vars = {};
        const assign = /local\s+(\w+)\s*=\s*["']([^"'\n]*)["']/g;
        for (let a = assign.exec(src); a !== null; a = assign.exec(src))
            vars[a[1]] = a[2];
        const value = text => {
            text = text.trim();
            const q = /^["']([\s\S]*)["']$/.exec(text);
            if (q)
                return q[1];
            // "kitty " .. "--single" or a variable, joined back together.
            return text.split("..").map(p => {
                p = p.trim();
                const s = /^["']([\s\S]*)["']$/.exec(p);
                return s ? s[1] : (vars[p] ?? p);
            }).join("");
        };

        const out = {};
        const re = /hl\.bind\s*\(\s*["']([^"']+)["']\s*,/g;
        let m;
        while ((m = re.exec(src)) !== null) {
            // The rest of the call, brackets balanced.
            let depth = 1, i = re.lastIndex, inStr = "";
            for (; i < src.length && depth > 0; i++) {
                const c = src[i];
                if (inStr) {
                    if (c === inStr && src[i - 1] !== "\\")
                        inStr = "";
                } else if (c === '"' || c === "'") {
                    inStr = c;
                } else if (c === "(" || c === "{") {
                    depth++;
                } else if (c === ")" || c === "}") {
                    depth--;
                }
            }
            const body = src.slice(re.lastIndex, i - 1);

            // A comment on the same line, or the line just above, says it best.
            const lineEnd = src.indexOf("\n", i);
            const tail = src.slice(i, lineEnd < 0 ? src.length : lineEnd);
            const before = src.slice(0, m.index).split("\n");
            const above = before.length >= 2 ? before[before.length - 2].trim() : "";
            const sameLine = /--\s*(.+)$/.exec(tail);
            let words = "";
            if (sameLine)
                words = sameLine[1].trim();
            else if (above.startsWith("--") && !before[before.length - 1].trim().startsWith("--"))
                words = above.replace(/^--+\s*/, "");

            if (words.length === 0 || words.length > 60) {
                const call = /hl\.dsp\.([\w.]+)\s*\(([^()]*(?:\([^()]*\)[^()]*)*)\)/.exec(body);
                if (call) {
                    const name = call[1].split(".").pop();
                    const arg = call[2].trim();
                    words = arg.startsWith("{") ? root.explainTable(call[1], arg, value) : root.explain(name, value(arg.split(/,(?![^(]*\))/)[0] ?? ""));
                } else if (/function/.test(body)) {
                    words = "a Lua function in your config";
                } else {
                    continue;
                }
            }

            const parts = m[1].split("+").map(p => p.trim()).filter(p => p.length > 0);
            const key = parts.pop() ?? "";
            const mods = parts.map(p => {
                const u = p.toUpperCase();
                return u === "CONTROL" ? "CTRL" : (u === "MOD4" || u === "WIN" || u === "META") ? "SUPER" : u;
            });
            out[`${root.maskOf(mods)}:${root.norm(key)}`] = words;
        }
        return out;
    }

    Process {
        id: luaSource

        command: ["sh", "-c", `find -L "${root.hyprDir}" -maxdepth 3 -name '*.lua' -not -name 'stratum-binds.lua' -exec cat {} + 2>/dev/null`]

        stdout: StdioCollector {
            onStreamFinished: root.luaWords = root.parseLua(text)
        }
    }

    function actionLabel(name) {
        return root.actions.find(a => a.name === name)?.label ?? name;
    }

    // Key names compared loosely: case, and the two names some keys go by.
    function norm(key) {
        const k = String(key ?? "").toLowerCase();
        const aliases = {
            "prior": "page_up", "next": "page_down", "pgup": "page_up", "pgdn": "page_down",
            "enter": "return", "esc": "escape", "del": "delete", "ins": "insert",
            "super": "super_l", "print": "print", "sysrq": "print"
        };
        return aliases[k] ?? k;
    }

    function maskOf(mods) {
        let m = 0;
        for (const [name, bit] of root.modBits)
            if (mods.includes(name))
                m |= bit;
        return m;
    }

    function modsOf(mask) {
        return root.modBits.filter(([, bit]) => (mask & bit) !== 0).map(([name]) => name);
    }

    function combo(mods, key) {
        return [...mods, key].join(" + ");
    }

    function forKey(key) {
        const k = root.norm(key);
        return root.all.filter(b => b.k === k);
    }

    // Two binds on one combination: Hyprland fires both, which is rarely meant.
    function conflicted(key) {
        const seen = {};
        for (const b of root.forKey(key)) {
            if (seen[b.mask])
                return true;
            seen[b.mask] = true;
        }
        return false;
    }

    function isOwn(mods, key) {
        const m = root.maskOf(mods);
        return root.own.some(b => root.maskOf(b.mods) === m && root.norm(b.key) === root.norm(key));
    }

    function addOwn(mods, key, action) {
        const m = root.maskOf(mods);
        const list = root.own.filter(b => !(root.maskOf(b.mods) === m && root.norm(b.key) === root.norm(key)));
        list.push({ mods: root.modBits.map(([n]) => n).filter(n => mods.includes(n)), key: key, action: action });
        root.save(list);
    }

    function removeOwn(mods, key) {
        const m = root.maskOf(mods);
        root.save(root.own.filter(b => !(root.maskOf(b.mods) === m && root.norm(b.key) === root.norm(key))));
    }

    function resetOwn() {
        Config.unset("keybinds.own");
        root.write(root.defaults);
    }

    function save(list) {
        Config.set("keybinds.own", list);
        root.write(list);
    }

    function flags(action) {
        if (["volumeUp", "volumeDown", "brightnessUp", "brightnessDown"].includes(action))
            return "repeating";
        if (["mediaToggle", "mediaNext", "mediaPrev", "volumeMute", "micMute", "screenshot",
                "screenshotRegion", "screenshotEdit", "record", "recordRegion"].includes(action))
            return "locked";
        return "";
    }

    function luaText(list) {
        const out = [
            "-- Stratum keybinds, written by Stratum's settings (the Keybinds page).",
            "-- Change them there: this file is rewritten whenever a bind is changed.",
            "--",
            "-- Loaded from your config with:",
            "--     dofile(os.getenv(\"HOME\") .. \"/.config/hypr/stratum-binds.lua\")",
            "",
            "local locked = { locked = true }",
            "local repeating = { locked = true, repeating = true }",
            "",
            "-- Anything already on these keys is dropped first, or Hyprland fires both.",
            "if type(hl.unbind) == \"function\" then"
        ];
        for (const b of list)
            out.push(`    pcall(hl.unbind, "${root.combo(b.mods, b.key)}")`);
        out.push("end", "");
        for (const b of list) {
            const f = root.flags(b.action);
            out.push(`hl.bind("${root.combo(b.mods, b.key)}", hl.dsp.global("stratum:${b.action}")${f ? ", " + f : ""})`);
        }
        return out.join("\n") + "\n";
    }

    function confText(list) {
        const out = [
            "# Stratum keybinds, written by Stratum's settings (the Keybinds page).",
            "# Change them there: this file is rewritten whenever a bind is changed.",
            "#",
            "# Loaded from hyprland.conf with:",
            "#     source = ~/.config/hypr/stratum-binds.conf",
            ""
        ];
        for (const b of list)
            out.push(`unbind = ${b.mods.join(" ")}, ${b.key}`);
        out.push("");
        for (const b of list) {
            const f = root.flags(b.action);
            const kind = f === "repeating" ? "bindle" : (f === "locked" ? "bindl" : "bind");
            out.push(`${kind} = ${b.mods.join(" ")}, ${b.key}, global, stratum:${b.action}`);
        }
        return out.join("\n") + "\n";
    }

    function write(list) {
        file.path = `${root.hyprDir}/stratum-binds.${root.lua ? "lua" : "conf"}`;
        file.setText(root.lua ? root.luaText(list) : root.confText(list));
    }

    function refresh() {
        if (!reader.running)
            reader.running = true;
        if (!luaSource.running)
            luaSource.running = true;
    }

    FileView {
        id: file

        // A path is only given at write time.
        preload: false
        watchChanges: false
        atomicWrites: true
        onSaved: reload.running = true
        onSaveFailed: error => root.error = `could not write ${file.path}`
    }

    Process {
        id: reload

        command: ["hyprctl", "reload"]
        onExited: settle.restart()
    }

    // Give Hyprland a moment to finish reloading before reading its binds back.
    Timer {
        id: settle

        interval: 500
        onTriggered: root.refresh()
    }

    Process {
        id: kind

        running: true
        command: ["sh", "-c", `[ -f "${root.hyprDir}/hyprland.lua" ] && echo lua || echo conf`]

        stdout: StdioCollector {
            onStreamFinished: root.lua = text.trim() === "lua"
        }
    }

    Process {
        id: reader

        command: ["hyprctl", "binds", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try {
                    list = JSON.parse(text);
                } catch (e) {
                    root.error = "could not read Hyprland's binds";
                    return;
                }
                root.error = "";
                root.all = list.filter(b => !b.mouse && (b.submap ?? "") === "").map(b => {
                    const mask = (b.modmask ?? 0) & ~root.ignoredBits;
                    const arg = String(b.arg ?? "");
                    return {
                        mods: root.modsOf(mask),
                        mask: mask,
                        key: b.key,
                        k: root.norm(b.key),
                        dispatcher: b.dispatcher ?? "",
                        arg: arg,
                        description: b.description ?? "",
                        stratum: arg.startsWith("stratum:")
                    };
                });
            }
        }
    }
}
