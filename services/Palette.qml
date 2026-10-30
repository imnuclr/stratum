pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme

/*
 * Colours taken from the wallpaper, through matugen.
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

    onModeChanged: root.refresh()
    onImageChanged: root.refresh()
    Connections {
        target: Theme

        function onDarkChanged() {
            root.refresh();
        }
    }

    function refresh() {
        if (root.mode === "off" || root.image.length === 0) {
            Theme.generated = ({});
            return;
        }
        const known = root.cache[root.image];
        if (known) {
            Theme.generated = root.tokensFrom(known);
            return;
        }
        if (!root.available || probe.running || matugen.running)
            return;
        root.running = root.image;
        matugen.command = [root.binary, "image", root.image, "--json", "hex", "--dry-run"];
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

    Process {
        id: probe

        running: true
        command: ["sh", "-c", Bin.finder, "sh", "matugen"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.binary = text.trim();
                root.refresh();
            }
        }
    }

    Process {
        id: matugen

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.running !== root.image)
                    return root.refresh();
                let scheme = null;
                try {
                    scheme = JSON.parse(text);
                } catch (e) {
                    root.error = "matugen printed something that is not JSON";
                    return;
                }
                root.error = "";
                const next = Object.assign({}, root.cache);
                next[root.running] = scheme;
                root.cache = next;
                Theme.generated = root.tokensFrom(scheme);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.error = text.trim().split("\n")[0];
            }
        }
    }
}
