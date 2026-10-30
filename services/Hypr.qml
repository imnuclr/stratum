pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

/*
 * Semantic wrapper over Hyprland dispatch.
 *
 * Hyprland 0.5x can run its config in Lua, and in that mode the IPC dispatch
 * argument is evaluated as Lua: `workspace 2` fails with "attempt to call a nil
 * value" and the plain string form never works. The Lua equivalent is
 * `hl.dsp.focus({ workspace = "2" })`.
 *
 * Caelestia branches on usingLua at every call site, which puts a ternary in
 * eight separate files. Keeping the split here means call sites just say what
 * they want and stay readable when one of the two forms eventually goes away.
 */
Singleton {
    id: root

    readonly property bool lua: Hyprland.usingLua

    readonly property var workspaces: Hyprland.workspaces?.values ?? []
    readonly property var toplevels: Hyprland.toplevels?.values ?? []
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace
    readonly property var activeToplevel: Hyprland.activeToplevel

    /*
     * Changes one output's resolution and refresh rate, keeping where it sits and
     * its scale. `monitor` is the object from `hyprctl -j monitors`.
     */
    /*
     * Runs Lua in Hyprland's config at runtime, for settings (hl.config) and
     * outputs (hl.monitor). There is no direct way in: a dispatch arrives as
     * `return hl.dispatch(<what was sent>)`, and hl.dispatch takes only an
     * action, so sending hl.config(...) was refused every time. Sent instead is
     * a function that runs the Lua — guarded, so a statement Hyprland rejects
     * does not stop the ones after it — and returns a harmless action.
     */
    function runLua(statements) {
        const body = [].concat(statements).map(st => `pcall(function() ${st} end)`).join(" ");
        Hyprland.dispatch(`(function() ${body} return hl.dsp.exec_cmd("true") end)()`);
    }

    function configure(table) {
        root.runLua(`hl.config(${table})`);
    }

    function setMonitorMode(monitor, width, height, hz) {
        const mode = `${width}x${height}@${hz}`;
        const pos = `${monitor.x}x${monitor.y}`;
        if (lua) {
            root.runLua(`hl.monitor({ output = "${monitor.name}", mode = "${mode}", position = "${pos}", scale = ${monitor.scale} })`);
        } else {
            modeProc.command = ["hyprctl", "keyword", "monitor", `${monitor.name},${mode},${pos},${monitor.scale}`];
            modeProc.running = true;
        }
    }

    Process {
        id: modeProc
    }

    /*
     * Window blur and shadows, off to save power or back on. Off is set
     * directly; on is a config reload, which puts back whatever your own
     * config says rather than guessing what it was.
     */
    function setEffects(on) {
        if (on) {
            Quickshell.execDetached(["hyprctl", "reload"]);
        } else if (lua) {
            root.configure("{ decoration = { blur = { enabled = false }, shadow = { enabled = false } } }");
        } else {
            Quickshell.execDetached(["hyprctl", "--batch", "keyword decoration:blur:enabled 0 ; keyword decoration:shadow:enabled 0"]);
        }
    }

    function focusWorkspace(id) {
        Hyprland.dispatch(lua ? `hl.dsp.focus({ workspace = "${id}" })` : `workspace ${id}`);
    }

    function focusWorkspaceRelative(delta) {
        const target = `r${delta > 0 ? "+" : "-"}${Math.abs(delta)}`;
        Hyprland.dispatch(lua ? `hl.dsp.focus({ workspace = "${target}" })` : `workspace ${target}`);
    }

    /*
     * Focus one window by address. The wayland handle's activate() looked like
     * the tidier route — it is what the capture source is taken from, so it is
     * known good — but it does not move Hyprland's focus, so clicking a window in
     * the overview did nothing. A dispatch does.
     */
    /*
     * Brings an application forward by name. Hyprland matches a class as a
     * regular expression, so the name is anchored and escaped — an app id with a
     * dot in it would otherwise match more than itself.
     */
    function focusApp(name) {
        if (!name)
            return;
        const pattern = `^${name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`;
        Hyprland.dispatch(lua
            ? `hl.dsp.focus({ window = "class:${pattern}" })`
            : `focuswindow class:${pattern}`);
    }

    /*
     * Moves a window (by a Hyprland window selector, e.g.
     * "title:^(Stratum Settings)$") to the workspace in front of you and
     * focuses it.
     */
    function bringWindow(selector) {
        const here = root.focusedWorkspace?.id ?? 1;
        Hyprland.dispatch(lua
            ? `hl.dsp.window.move({ window = "${selector}", workspace = "${here}", follow = false })`
            : `movetoworkspacesilent ${here},${selector}`);
        Hyprland.dispatch(lua
            ? `hl.dsp.focus({ window = "${selector}" })`
            : `focuswindow ${selector}`);
    }

    function focusWindow(address) {
        if (!address)
            return;
        Hyprland.dispatch(lua
            ? `hl.dsp.focus({ window = "address:${address}" })`
            : `focuswindow address:${address}`);
    }

    function toggleSpecial(name) {
        Hyprland.dispatch(lua ? `hl.dsp.workspace.toggle_special("${name}")` : `togglespecialworkspace ${name}`);
    }

    function windowsOn(workspaceId) {
        return workspaces.find(w => w.id === workspaceId)?.toplevels?.values?.length ?? 0;
    }

    // Which monitor a workspace is on, or "" if it does not exist yet. Hyprland
    // creates a workspace when it is first used, so most of them have no answer.
    function monitorOf(workspaceId) {
        return workspaces.find(w => w.id === workspaceId)?.monitor?.name ?? "";
    }

    /*
     * The ids worth showing: the configured run, extended to cover anything that
     * actually exists. A fixed count meant switching past the end of it left no
     * dot to light up and the bar simply stopped reporting where you were.
     */
    function visibleIds(configured) {
        let highest = configured;
        for (const w of workspaces)
            if (w.id > highest && w.id < 100)
                highest = w.id;
        const ids = [];
        for (let i = 1; i <= highest; i++)
            ids.push(i);
        return ids;
    }

    function isOccupied(workspaceId) {
        return workspaces.some(w => w.id === workspaceId);
    }
}
