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

    /*
     * The user's file as an object, held in memory.
     *
     * set() edits this and the write to disk follows, rather than reading the
     * file back each time. A slider calls set() on every frame of a drag, and a
     * read-modify-write against a file that has not caught up loses all but the
     * last change — or, worse, restores an older one when the watcher fires for
     * a write that has already been superseded.
     */
    property var user: ({})
    property var defaults: ({})
    // A change is waiting to be written; the file on disk is behind `user`.
    property bool dirty: false

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

        root.defaults = defaults;
        // While a write is pending the file is the stale side: re-reading it now
        // would throw away what the person just changed.
        if (!root.dirty)
            root.user = user;
        root.values = merge(defaults, root.user);
        root.ready = true;
    }

    /*
     * Writes one value into the user's file, creating the path to it.
     *
     * Refuses outright when the file could not be read. An unparseable file is
     * usually a typo mid-edit, and writing now would replace everything else in
     * it with this one key.
     */
    function set(keyPath, value) {
        if (root.error.length > 0)
            return false;

        const keys = keyPath.split(".");
        const next = JSON.parse(JSON.stringify(root.user));
        let node = next;
        for (const key of keys.slice(0, -1)) {
            if (!node[key] || typeof node[key] !== "object" || Array.isArray(node[key]))
                node[key] = {};
            node = node[key];
        }
        node[keys[keys.length - 1]] = value;
        root.commit(next);
        return true;
    }

    // Removes a key so the default shows through again, pruning parents it empties.
    function unset(keyPath) {
        if (root.error.length > 0)
            return false;

        const keys = keyPath.split(".");
        const next = JSON.parse(JSON.stringify(root.user));
        const trail = [next];
        let node = next;
        for (const key of keys.slice(0, -1)) {
            if (!node[key] || typeof node[key] !== "object")
                return true;
            node = node[key];
            trail.push(node);
        }
        delete node[keys[keys.length - 1]];
        for (let i = trail.length - 1; i > 0; i--) {
            if (Object.keys(trail[i]).length > 0)
                break;
            delete trail[i - 1][keys[i - 1]];
        }
        root.commit(next);
        return true;
    }

    function commit(next) {
        root.user = next;
        root.dirty = true;
        // Live at once; the disk catches up behind it.
        root.values = merge(root.defaults, next);
        writer.restart();
    }

    Timer {
        id: writer

        interval: 300
        onTriggered: userFile.setText(JSON.stringify(root.user, null, 2) + "\n")
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
        // The disk has caught up, so a re-read is trustworthy again.
        onSaved: root.dirty = false
    }
}
