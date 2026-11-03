pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Which application opens which kind of file.
 *
 * Read and written through `gio mime`, the same defaults every other desktop
 * app consults (they live in ~/.config/mimeapps.list). A format is one or more
 * MIME types: "Web links" is both http and https, so one choice covers it.
 *
 * `state` maps a MIME type to { current: desktop id, apps: [desktop ids] },
 * replaced whole on every change so anything reading it is told.
 */
Singleton {
    id: root

    // What the page lists, by card. `mimes` is what the choice is applied to;
    // the first one is what is read back.
    readonly property var groups: [
        { title: "images", formats: [
            { title: ".png", detail: "PNG image", mimes: ["image/png"] },
            { title: ".jpg", detail: "JPEG image", mimes: ["image/jpeg"] },
            { title: ".gif", detail: "GIF image", mimes: ["image/gif"] },
            { title: ".webp", detail: "WebP image", mimes: ["image/webp"] },
            { title: ".avif", detail: "AVIF image", mimes: ["image/avif"] },
            { title: ".svg", detail: "SVG drawing", mimes: ["image/svg+xml"] }
        ] },
        { title: "video and music", formats: [
            { title: ".mp4", detail: "MPEG-4 video", mimes: ["video/mp4"] },
            { title: ".mkv", detail: "Matroska video", mimes: ["video/x-matroska"] },
            { title: ".webm", detail: "WebM video", mimes: ["video/webm"] },
            { title: ".mp3", detail: "MP3 audio", mimes: ["audio/mpeg"] },
            { title: ".flac", detail: "FLAC audio", mimes: ["audio/flac"] },
            { title: ".wav", detail: "WAV audio", mimes: ["audio/x-wav"] }
        ] },
        { title: "documents", formats: [
            { title: ".pdf", detail: "PDF document", mimes: ["application/pdf"] },
            { title: ".txt", detail: "Plain text", mimes: ["text/plain"] },
            { title: ".md", detail: "Markdown", mimes: ["text/markdown"] },
            { title: ".epub", detail: "E-book", mimes: ["application/epub+zip"] }
        ] },
        { title: "archives", formats: [
            { title: ".zip", detail: "ZIP archive", mimes: ["application/zip"] },
            { title: ".7z", detail: "7-Zip archive", mimes: ["application/x-7z-compressed"] },
            { title: ".tar.gz", detail: "Compressed tarball", mimes: ["application/gzip"] },
            { title: ".rar", detail: "RAR archive", mimes: ["application/vnd.rar"] }
        ] },
        { title: "links and folders", formats: [
            { title: "Web links", detail: "http and https, and .html pages", mimes: ["x-scheme-handler/https", "x-scheme-handler/http", "text/html"] },
            { title: "Email links", detail: "mailto:", mimes: ["x-scheme-handler/mailto"] },
            { title: "Folders", detail: "Opening a folder", mimes: ["inode/directory"] }
        ] }
    ]

    property var state: ({})

    // A format typed in by hand, once found: { title, mimes }.
    property var custom: null
    property string customError: ""

    readonly property var allMimes: {
        const all = [];
        for (const g of root.groups)
            for (const f of g.formats)
                all.push(...f.mimes);
        return all;
    }

    Component.onCompleted: root.read(root.allMimes)

    function read(mimes) {
        reader.command = ["sh", "-c", `
            export LC_ALL=C
            for m in "$@"; do printf '@@%s\\n' "$m"; gio mime "$m" 2>/dev/null; done`, "sh", ...mimes];
        reader.running = false;
        reader.running = true;
    }

    // "@@mime", then gio's own listing: the default, then everything that
    // says it can open the type.
    function parse(text) {
        const next = Object.assign({}, root.state);
        for (const block of text.split("@@").slice(1)) {
            const lines = block.split("\n");
            const mime = lines[0].trim();
            const entry = { current: "", apps: [] };
            let listing = false;
            for (const line of lines.slice(1)) {
                const d = line.match(/^Default application for .*: (\S+\.desktop)\s*$/);
                if (d)
                    entry.current = d[1];
                if (line.startsWith("Registered applications"))
                    listing = true;
                else if (line.startsWith("Recommended applications"))
                    listing = false;
                else if (listing && /\.desktop\s*$/.test(line) && !entry.apps.includes(line.trim()))
                    entry.apps.push(line.trim());
            }
            next[mime] = entry;
        }
        root.state = next;
    }

    Process {
        id: reader

        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function nameOf(id) {
        const entry = DesktopEntries.byId(id.replace(/\.desktop$/, "")) ?? DesktopEntries.byId(id);
        return entry?.name ?? id.replace(/\.desktop$/, "");
    }

    // What to show for each application that can open the format. Two with the
    // same name (a browser installed twice) are told apart by their ids.
    function choices(mime) {
        const ids = root.state[mime]?.apps ?? [];
        const names = ids.map(root.nameOf);
        return ids.map((id, i) => names.filter(n => n === names[i]).length > 1
            ? `${names[i]} · ${id.replace(/\.desktop$/, "")}` : names[i]);
    }

    function currentIndex(mime) {
        return (root.state[mime]?.apps ?? []).indexOf(root.state[mime]?.current ?? "");
    }

    function choose(format, index) {
        const id = root.state[format.mimes[0]]?.apps[index];
        if (!id)
            return;
        // gio takes one type at a time.
        setter.command = ["sh", "-c", 'id="$1"; shift; for m in "$@"; do gio mime "$m" "$id" >/dev/null; done', "sh", id, ...format.mimes];
        setter.mimes = format.mimes;
        setter.running = false;
        setter.running = true;
    }

    Process {
        id: setter

        property var mimes: []

        onExited: root.read(setter.mimes)
    }

    // ".psd" or "psd" -> its MIME type, from the system's own table of globs.
    function lookup(text) {
        const ext = text.trim().replace(/^\*?\./, "").toLowerCase();
        root.custom = null;
        root.customError = "";
        if (ext.length === 0 || /[^a-z0-9+_-]/.test(ext)) {
            root.customError = ext.length === 0 ? "" : "Type an extension, like psd.";
            return;
        }
        finder.ext = ext;
        finder.command = ["sh", "-c", `awk -F: -v e="*.$1" 'tolower($3) == e { print $2; exit }' /usr/share/mime/globs2 "$HOME/.local/share/mime/globs2" 2>/dev/null`, "sh", ext];
        finder.running = false;
        finder.running = true;
    }

    Process {
        id: finder

        property string ext: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const mime = text.trim();
                if (mime.length === 0) {
                    root.customError = `Nothing knows what .${finder.ext} is.`;
                    return;
                }
                root.custom = { title: `.${finder.ext}`, detail: mime, mimes: [mime] };
                root.read([mime]);
            }
        }
    }
}
