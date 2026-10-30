pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*
 * Searching for things to open: applications, files, the shell's own settings
 * and actions, and sums. The window (modules/launcher) asks and shows; this holds
 * how matches are scored, which apps are used most, and the file search.
 *
 * Apps you open more often rank higher, so after a few days the one you want is
 * usually first for its first letter. Counts live in the state directory.
 */
Singleton {
    id: root

    // How often each app has been launched from here, by desktop entry id.
    property var counts: ({})

    // Text to start with on the next open, from `launcher search`.
    property string preset: ""

    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/stratum/launcher.json`

    readonly property var apps: (DesktopEntries.applications?.values ?? []).filter(e => !e.noDisplay)

    // Files matching the last query long enough to search for.
    property var files: []
    property string fileQuery: ""

    /*
     * How well `text` answers `query`, 0 for not at all. Whole match, then a
     * prefix, then the start of any word, then anywhere, then the letters in
     * order — which is what lets "vsc" find Visual Studio Code.
     */
    function score(text, query) {
        if (!text)
            return 0;
        const t = String(text).toLowerCase();
        const q = query.toLowerCase();
        if (q.length === 0)
            return 1;
        if (t === q)
            return 100;
        if (t.startsWith(q))
            return 80;
        if (t.split(/[\s\-_.]+/).some(w => w.startsWith(q)))
            return 62;
        const at = t.indexOf(q);
        if (at >= 0)
            return 40 - Math.min(20, at);
        let j = 0;
        for (const c of t) {
            if (c === q[j])
                j++;
            if (j === q.length)
                break;
        }
        return j === q.length ? 12 : 0;
    }

    function appScore(entry, query) {
        const best = Math.max(
            root.score(entry.name, query),
            root.score(entry.genericName, query) * 0.8,
            ...(entry.keywords ?? []).map(k => root.score(k, query) * 0.7),
            root.score(entry.id, query) * 0.6);
        if (best === 0)
            return 0;
        return best + Math.log((root.counts[entry.id] ?? 0) + 1) * 6;
    }

    function rankApps(query, limit) {
        if (query.length === 0) {
            // Nothing typed: what you use most, then the rest alphabetically.
            return root.apps.slice()
                .sort((a, b) => (root.counts[b.id] ?? 0) - (root.counts[a.id] ?? 0) || a.name.localeCompare(b.name))
                .slice(0, limit);
        }
        return root.apps
            .map(e => ({ e: e, s: root.appScore(e, query) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s)
            .slice(0, limit)
            .map(x => x.e);
    }

    function forget() {
        root.counts = ({});
        writer.restart();
    }

    function launched(entry) {
        const next = Object.assign({}, root.counts);
        next[entry.id] = (next[entry.id] ?? 0) + 1;
        root.counts = next;
        writer.restart();
    }

    // A sum, if the query is one: digits, operators and brackets only.
    function calc(query) {
        const q = query.replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, ".");
        if (!/^[0-9.+\-*/()%^]+$/.test(q) || !/[+\-*/%^]/.test(q) || !/[0-9]/.test(q))
            return null;
        try {
            const v = Function(`"use strict"; return (${q.replace(/\^/g, "**")});`)();
            if (typeof v !== "number" || !isFinite(v))
                return null;
            return Math.round(v * 1e10) / 1e10;
        } catch (e) {
            return null;
        }
    }

    // Files opened lately, newest first, from the desktop's shared history.
    property var recent: []

    function loadRecent() {
        recents.running = true;
    }

    Process {
        id: recents

        command: ["sh", "-c", `f="\${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel"; [ -f "$f" ] && grep -o 'href="file://[^"]*"' "$f" | tail -n 80`]

        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set();
                const out = [];
                for (const line of text.split("\n").reverse()) {
                    const m = /href="file:\/\/([^"]*)"/.exec(line);
                    if (!m)
                        continue;
                    let path = m[1];
                    try {
                        path = decodeURIComponent(path);
                    } catch (e) {}
                    if (seen.has(path))
                        continue;
                    seen.add(path);
                    out.push(path);
                }
                root.recent = out.slice(0, 30);
            }
        }
    }

    function searchFiles(query) {
        root.fileQuery = query;
        if (query.length < 3 || !Config.get("launcher.files", true)) {
            root.files = [];
            return;
        }
        fileDelay.restart();
    }

    Timer {
        id: fileDelay

        interval: 180
        onTriggered: {
            finder.running = false;
            finder.command = ["sh", "-c", `
                q="$1"
                if command -v plocate >/dev/null 2>&1; then
                    plocate -i -l 60 -- "$q" 2>/dev/null | grep -v '/\\.' | grep "^$HOME" | head -n 24
                elif command -v fd >/dev/null 2>&1; then
                    fd -i --max-results 24 --max-depth 6 -- "$q" "$HOME" 2>/dev/null
                else
                    find "$HOME" -maxdepth 5 -not -path '*/.*' -iname "*$q*" 2>/dev/null | head -n 24
                fi`, "sh", root.fileQuery];
            finder.running = true;
        }
    }

    Process {
        id: finder

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.length > 0);
                root.files = lines.slice(0, 24);
            }
        }
    }

    Timer {
        id: writer

        interval: 600
        onTriggered: state.setText(JSON.stringify({ counts: root.counts }) + "\n")
    }

    FileView {
        id: state

        path: root.statePath
        preload: true
        onLoaded: {
            try {
                root.counts = JSON.parse(state.text()).counts ?? ({});
            } catch (e) {
                root.counts = ({});
            }
        }
        onLoadFailed: root.counts = ({})
    }
}
