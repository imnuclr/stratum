pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

/*
 * Every connected output as Hyprland sees it, and changing how each one runs:
 * resolution, refresh rate, scale and where it sits beside the others.
 *
 * Changes are tried first and only kept once confirmed, the way a display
 * settings panel should behave: a mode the screen cannot show leaves you
 * looking at nothing, so an unconfirmed change undoes itself after a few
 * seconds. Kept settings live in the shell's own config (`displays.<name>`) and
 * are put back at startup, when a screen is plugged in, and after Hyprland
 * reloads — so nothing in your Hyprland config is ever edited.
 */
Singleton {
    id: root

    // From `hyprctl monitors -j`: name, description, make, model, width, height,
    // refreshRate, x, y, scale, availableModes, ...
    property var list: []

    // What the outputs were before the change being tried, by name.
    property var before: null
    readonly property bool trying: root.before !== null
    property int countdown: 0

    function byName(name) {
        return root.list.find(m => m.name === name) ?? null;
    }

    // Distinct resolutions an output offers, largest first, as { w, h, rates }.
    function modesOf(monitor) {
        const out = {};
        for (const mode of monitor?.availableModes ?? []) {
            const hit = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(mode);
            if (!hit)
                continue;
            const key = `${hit[1]}x${hit[2]}`;
            out[key] = out[key] ?? { w: Number(hit[1]), h: Number(hit[2]), rates: [] };
            const hz = Number(hit[3]);
            if (!out[key].rates.some(r => Math.abs(r - hz) < 0.5))
                out[key].rates.push(hz);
        }
        return Object.values(out)
            .map(m => Object.assign(m, { rates: m.rates.sort((a, b) => b - a) }))
            .sort((a, b) => b.w * b.h - a.w * a.h);
    }

    function settingsOf(m) {
        return { width: m.width, height: m.height, hz: m.refreshRate, x: m.x, y: m.y, scale: m.scale };
    }

    function line(name, s) {
        const mode = `${s.width}x${s.height}@${Number(s.hz).toFixed(2)}`;
        const pos = `${Math.round(s.x)}x${Math.round(s.y)}`;
        const scale = Math.round(s.scale * 1000) / 1000;
        return Hypr.lua
            ? `hl.monitor({ output = "${name}", mode = "${mode}", position = "${pos}", scale = ${scale} })`
            : `${name},${mode},${pos},${scale}`;
    }

    function send(changes) {
        for (const name of Object.keys(changes)) {
            if (Hypr.lua) {
                Hyprland.dispatch(root.line(name, changes[name]));
            } else {
                Quickshell.execDetached(["hyprctl", "keyword", "monitor", root.line(name, changes[name])]);
            }
        }
        settle.restart();
    }

    /*
     * Tries new settings for some outputs: { name: { width, height, hz, x, y,
     * scale } }, each field optional. Starts the countdown to undo them.
     */
    function attempt(changes) {
        if (!root.trying) {
            const snap = {};
            for (const m of root.list)
                snap[m.name] = root.settingsOf(m);
            root.before = snap;
        }
        const full = {};
        for (const name of Object.keys(changes)) {
            const m = root.byName(name);
            if (m)
                full[name] = Object.assign(root.settingsOf(m), changes[name]);
        }
        root.send(full);
        root.countdown = 15;
        tick.restart();
    }

    function keep() {
        tick.stop();
        root.before = null;
        const saved = Object.assign({}, Config.get("displays", {}) ?? {});
        for (const m of root.list)
            saved[m.name] = root.settingsOf(m);
        Config.set("displays", saved);
    }

    function revert() {
        tick.stop();
        if (root.before)
            root.send(root.before);
        root.before = null;
    }

    // Puts kept settings back on whatever is plugged in.
    function restore() {
        const saved = Config.get("displays", {}) ?? {};
        const changes = {};
        for (const m of root.list) {
            const s = saved[m.name];
            if (!s)
                continue;
            const now = root.settingsOf(m);
            const same = s.width === now.width && s.height === now.height && Math.abs(s.hz - now.hz) < 0.5
                && Math.round(s.x) === now.x && Math.round(s.y) === now.y && Math.abs(s.scale - now.scale) < 0.01;
            if (!same)
                changes[m.name] = s;
        }
        if (Object.keys(changes).length > 0)
            root.send(changes);
    }

    // Forgets what was kept, so the next reload uses your Hyprland config again.
    function forget(name) {
        const saved = Object.assign({}, Config.get("displays", {}) ?? {});
        delete saved[name];
        Config.set("displays", saved);
    }

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    property bool restored: false

    Timer {
        id: tick

        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown--;
            if (root.countdown <= 0)
                root.revert();
        }
    }

    // Hyprland applies a mode change over a few frames; read back after.
    Timer {
        id: settle

        interval: 400
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const n = event.name;
            if (n === "monitoradded" || n === "monitoraddedv2" || n === "configreloaded") {
                root.restored = false;
                root.refresh();
            } else if (n === "monitorremoved") {
                root.refresh();
            }
        }
    }

    Process {
        id: reader

        running: true
        command: ["hyprctl", "monitors", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.list = JSON.parse(text).filter(m => !m.disabled);
                } catch (e) {
                    return;
                }
                if (!root.restored && !root.trying) {
                    root.restored = true;
                    root.restore();
                }
            }
        }
    }
}
