pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * The to-do list in the sidebar.
 *
 * Open tasks first, completed ones under a "done" heading, which is also the
 * order the file is stored in. Ticking one moves it to the bottom; un-ticking
 * puts it back at the end of the open group.
 *
 * A ListModel rather than an array so the view can animate an insertion, a
 * removal and a move instead of resetting itself and rebuilding every row. The
 * file is still plain JSON: the model's roles are written out together.
 */
Singleton {
    id: root

    readonly property string path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/stratum/notes.json`

    ListModel {
        id: store
    }

    // Bumped by every change. A ListModel does not notify a binding that only
    // walked it, so the counts read this.
    property int revision: 0

    readonly property ListModel items: store
    readonly property int count: store.count
    readonly property int openCount: {
        void root.revision;
        let open = 0;
        for (let i = 0; i < store.count; i++)
            if (!store.get(i).done)
                open++;
        return open;
    }
    readonly property int doneCount: root.count - root.openCount

    function uid() {
        return Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36);
    }

    function indexOf(key) {
        for (let i = 0; i < store.count; i++)
            if (store.get(i).key === key)
                return i;
        return -1;
    }

    function serialised() {
        const items = [];
        for (let i = 0; i < store.count; i++)
            items.push(store.get(i));
        return JSON.stringify({ items: items }, null, 2) + "\n";
    }

    function save() {
        writer.restart();
    }

    function changed() {
        root.revision++;
        root.save();
    }

    function add(text) {
        const value = String(text ?? "").trim();
        if (value.length === 0)
            return;
        store.insert(0, {
            key: root.uid(),
            text: value,
            done: false,
            group: "open",
            at: Date.now()
        });
        root.changed();
    }

    function toggle(key) {
        const at = root.indexOf(key);
        if (at < 0)
            return;

        const done = !store.get(at).done;
        store.setProperty(at, "done", done);
        store.setProperty(at, "group", done ? "done" : "open");

        if (done) {
            // Completed tasks sink beneath the open ones.
            store.move(at, store.count - 1, 1);
        } else {
            // Back to the end of the open group, which now includes this one.
            let open = 0;
            for (let i = 0; i < store.count; i++)
                if (!store.get(i).done)
                    open++;
            if (at > open - 1)
                store.move(at, open - 1, 1);
        }
        root.changed();
    }

    function remove(key) {
        const at = root.indexOf(key);
        if (at < 0)
            return;
        store.remove(at, 1);
        root.changed();
    }

    function clearDone() {
        for (let i = store.count - 1; i >= 0; i--)
            if (store.get(i).done)
                store.remove(i, 1);
        root.changed();
    }

    Timer {
        id: writer

        interval: 250
        onTriggered: file.setText(root.serialised())
    }

    FileView {
        id: file

        path: root.path
        preload: true
        // A missing file is the first run, not a fault. It is created empty so
        // the next start has something to read and the log stays quiet.
        onLoadFailed: err => {
            store.clear();
            root.revision++;
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => file.setText(root.serialised()));
        }
        onLoaded: {
            try {
                const data = JSON.parse(file.text());
                const items = Array.isArray(data.items)
                    ? data.items.filter(item => item && typeof item.text === "string").map(item => ({
                        // Older files wrote the key as `id`; it cannot be a
                        // delegate property here, since `id` is QML's own.
                        key: String(item.key ?? item.id ?? root.uid()),
                        text: item.text,
                        done: !!item.done,
                        group: item.done ? "done" : "open",
                        at: Number(item.at) || 0
                    }))
                    : [];
                const ordered = items.filter(item => !item.done).concat(items.filter(item => item.done));
                store.clear();
                for (const item of ordered)
                    store.append(item);
                root.revision++;
            } catch (e) {
                console.log(`[notes] ${root.path} is not valid JSON; starting empty`);
                store.clear();
                root.revision++;
            }
        }
    }
}
