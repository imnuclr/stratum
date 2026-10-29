pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Behaviour config. Watches ~/.config/stratum/shell.json and republishes on write,
 * so every binding downstream updates without a reload.
 *
 * Reads are always safe: a missing or malformed file falls back to defaults/shell.json,
 * and `ready` stays false so callers can tell the difference.
 */
Singleton {
    id: root

    readonly property string path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/stratum/shell.json`

    property bool ready: false
    property string error: ""

    // Merged defaults <- user. Modules read through this, never through `file`.
    property var values: ({})

    function get(keyPath, fallback) {
        let node = values;
        for (const key of keyPath.split(".")) {
            if (node === undefined || node === null || typeof node !== "object")
                return fallback;
            node = node[key];
        }
        return node === undefined ? fallback : node;
    }

    // Per-monitor override: monitors[name].<keyPath>, falling back to the global value.
    function forMonitor(screenName, keyPath, fallback) {
        const override = get(`monitors.${screenName}.${keyPath}`, undefined);
        return override === undefined ? get(keyPath, fallback) : override;
    }

    function merge(base, over) {
        const out = Object.assign({}, base);
        for (const [key, value] of Object.entries(over ?? {})) {
            const isObject = v => v && typeof v === "object" && !Array.isArray(v);
            out[key] = isObject(value) && isObject(base[key]) ? merge(base[key], value) : value;
        }
        return out;
    }

    function reload() {
        let defaults = {};
        try {
            defaults = JSON.parse(defaultsFile.text());
        } catch (e) {
            root.error = `defaults/shell.json is malformed: ${e.message}`;
            return;
        }

        let user = {};
        if (userFile.text().trim().length > 0) {
            try {
                user = JSON.parse(userFile.text());
                root.error = "";
            } catch (e) {
                root.error = `${root.path}: ${e.message}`;
                root.values = defaults;
                root.ready = false;
                return;
            }
        }

        root.values = merge(defaults, user);
        root.ready = true;
    }

    FileView {
        id: defaultsFile

        path: Quickshell.shellPath("config/defaults/shell.json")
        blockLoading: true
        onLoaded: root.reload()
    }

    FileView {
        id: userFile

        path: root.path
        watchChanges: true
        preload: true
        onLoaded: root.reload()
        onFileChanged: reload()
        // A missing user file is the normal first-run case, not an error.
        onLoadFailed: root.reload()
    }
}
