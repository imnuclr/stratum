pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

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

    function focusWorkspace(id) {
        Hyprland.dispatch(lua ? `hl.dsp.focus({ workspace = "${id}" })` : `workspace ${id}`);
    }

    function focusWorkspaceRelative(delta) {
        const target = `r${delta > 0 ? "+" : "-"}${Math.abs(delta)}`;
        Hyprland.dispatch(lua ? `hl.dsp.focus({ workspace = "${target}" })` : `workspace ${target}`);
    }

    function toggleSpecial(name) {
        Hyprland.dispatch(lua ? `hl.dsp.workspace.toggle_special("${name}")` : `togglespecialworkspace ${name}`);
    }

    function windowsOn(workspaceId) {
        return workspaces.find(w => w.id === workspaceId)?.toplevels?.values?.length ?? 0;
    }

    function isOccupied(workspaceId) {
        return workspaces.some(w => w.id === workspaceId);
    }
}
