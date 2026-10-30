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
