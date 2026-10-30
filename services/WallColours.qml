pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme
import qs.services

/*
 * Colours taken from the wallpaper, through matugen.
 *
 * Not called Palette: Qt Quick has a Palette type of its own, and in any file
 * that imports QtQuick that name meant Qt's, which has none of this — so the
 * setting read "matugen not installed" whatever was installed.
 *
 * Off by default, because the design is monochrome with one red and this is the
 * one thing that changes that. Two strengths, `theme.fromWallpaper` in shell.json:
 *   accent  only the emphasis colour follows the picture
 *   full    the surfaces take a faint tint of it as well
 * Text, lines and the semantic colours are never touched, so a warning still
 * reads as one whatever the wallpaper is.
 *
 * matugen's JSON has changed shape between releases, so the colours are looked
 * up in each of the forms it has used rather than in one. Results are kept per
 * image: switching back to a wallpaper already seen does not run it again.
 */
Singleton {
    id: root

    readonly property string mode: Config.get("theme.fromWallpaper", "off")
    // The first display's picture stands for the desktop when they differ.
    readonly property string image: Wallpaper.forMonitor(Quickshell.screens[0]?.name ?? "")

    // Found with the user's own bin directories on the path: the shell is often
    // started from somewhere that does not have them, and matugen is usually
    // installed with cargo.
    property string binary: ""
    readonly property bool available: root.binary.length > 0
    property string error: ""
    property var cache: ({})
    // Which image the running process is for, so a late answer cannot be applied
    // to a wallpaper that has since changed.
    property string running: ""
    // Whether this matugen understands --source-color-index (3.x does).
    property bool pickFlag: true

    onModeChanged: root.refresh()
    onImageChanged: root.refresh()
    Connections {
        target: Theme

        function onDarkChanged() {
            root.refresh();
        }
    }

    /*
     * The full scheme behind the shell's colours, for apps to be themed from:
     * the wallpaper's when colours come from it, otherwise one built from the
     * accent you picked. Either way the apps get a whole matched set — surfaces,
     * text, primary, secondary, tertiary — rather than one colour on grey.
     */
    property var scheme: null
    readonly property string key: root.mode !== "off" && root.image.length > 0
        ? root.image
        : `accent:${Theme.user?.color?.accent ?? Theme.preset?.color?.accent ?? "#E5252B"}`

    onKeyChanged: root.refresh()

    // One role from the scheme, for the current light or dark: "" if none.
    function role(name) {
        return root.scheme ? root.colour(root.scheme, name) : "";
    }

    function refresh() {
        const fromWall = root.mode !== "off" && root.image.length > 0;
        if (!fromWall)
            Theme.generated = ({});
        const known = root.cache[root.key];
        if (known) {
            root.scheme = known;
            if (fromWall)
                Theme.generated = root.tokensFrom(known);
            return;
        }
        if (!root.available || probe.running || matugen.running)
            return;
        root.running = root.key;
        if (!fromWall) {
            matugen.command = [root.binary, "color", "hex", root.key.slice("accent:".length), "--json", "hex", "--dry-run"];
            matugen.running = true;
            return;
        }
        /*
         * matugen 3 stops to ask which of the picture's colours to build from
         * when it finds several, and with nobody at a terminal it waits for ever
         * or fails. The index answers in advance; matugen 2 has no such flag,
         * so a refusal of it drops the flag and tries again.
         */
        matugen.command = [root.binary, "image", root.image, "--json", "hex", "--dry-run",
            ...(root.pickFlag ? ["--source-color-index", "0"] : [])];
        matugen.running = true;
    }

    // One named colour from whichever shape the JSON has.
    function colour(scheme, name) {
        const c = scheme.colors ?? {};
        const tone = Theme.dark ? "dark" : "light";
        const candidates = [
            c[tone]?.[name],
            c[name]?.[tone],
            c[name]?.[tone]?.color,
            c[name]?.default?.color,
            c[name]
        ];
        for (const v of candidates) {
            if (typeof v === "string" && /^#[0-9a-fA-F]{6,8}$/.test(v))
                return v;
        }
        return "";
    }

    function tokensFrom(scheme) {
        const out = { color: {} };
        const set = (token, name) => {
            const v = root.colour(scheme, name);
            if (v.length > 0)
                out.color[token] = v;
        };
        set("accent", "primary");
        if (root.mode === "full") {
            set("bg", "surface_container_lowest");
            set("panel", "surface_dim");
            set("surface", "surface_container_low");
            set("surfaceHi", "surface_container");
            set("surfaceTop", "surface_container_high");
        }
        return out;
    }

    /*
     * Where matugen was looked for, and what happened, for `stratum ipc palette
     * status` and the line under the setting.
     */
    property string searched: "not yet"
    // The path as configured, when it lives somewhere no search would find.
    readonly property string configured: Config.get("theme.matugen", "")

    // Looks for the program again: something installed after the shell started
    // is picked up the next time its settings are opened.
    function find() {
        // A path you gave is used as it is: nothing to search for.
        if (root.configured.length > 0) {
            root.binary = root.configured;
            root.searched = "set in config (theme.matugen)";
            root.refresh();
            return;
        }
        if (probe.running)
            return;
        root.searched = "searching";
        /*
         * The command is set here, at the moment of starting, rather than bound
         * on the Process with running: true. Bound, it could start before the
         * script it names had a value — the one search the shell ever made then
         * ran nothing, and matugen was "not installed" for good.
         */
        probe.command = ["sh", "-c", Bin.finder, "sh", "matugen"];
        probe.running = true;
    }

    Component.onCompleted: root.find()
    onConfiguredChanged: {
        root.binary = "";
        root.find();
    }

    Process {
        id: probe

        onExited: (code, status) => {
            if (root.binary.length === 0)
                root.searched = code === 0 ? "found nothing" : `not found (search exited ${code})`;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.trim().split("\n").pop() ?? "";
                if (found.length > 0) {
                    root.binary = found;
                    root.searched = `found ${found}`;
                }
                root.refresh();
            }
        }
    }

    Process {
        id: matugen

        property string complaint: ""
        property int code: 0

        // stderr may still be arriving when the process exits, so judged a
        // moment later.
        onExited: code => {
            matugen.code = code;
            if (code !== 0)
                judge.restart();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.running !== root.key)
                    return root.refresh();
                if (text.trim().length === 0)
                    return;
                let scheme = null;
                try {
                    // Some versions log a line or two before the JSON.
                    scheme = JSON.parse(text.slice(text.indexOf("{"), text.lastIndexOf("}") + 1));
                } catch (e) {
                    root.error = "matugen printed something that is not JSON";
                    return;
                }
                root.error = "";
                const next = Object.assign({}, root.cache);
                next[root.running] = scheme;
                root.cache = next;
                root.scheme = scheme;
                if (root.mode !== "off" && root.image.length > 0)
                    Theme.generated = root.tokensFrom(scheme);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                matugen.complaint = text.trim().split("\n").filter(l => l.trim().length > 0).pop() ?? "";
            }
        }
    }

    Timer {
        id: judge

        interval: 120
        onTriggered: {
            const code = matugen.code;
            if (root.pickFlag && /source-color-index|unexpected|unrecognized|wasn't expected/i.test(matugen.complaint)) {
                root.pickFlag = false;
                root.running = "";
                Qt.callLater(root.refresh);
                return;
            }
            root.error = matugen.complaint.length > 0 ? `matugen: ${matugen.complaint}` : `matugen stopped with code ${code}`;
        }
    }
}
