pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.theme

/*
 * The shell's colours, carried into your apps: terminals, GTK apps, Spotify
 * (through Spicetify) and Vesktop/Discord (through Vencord). Whatever the
 * shell is using — the accent you picked, light or dark, or matugen's palette —
 * is written as each app's own theme file whenever it changes.
 *
 * Each app's file is Stratum's own and separate from your config; the one line
 * that loads it is added to your config only when you switch that app on in
 * Settings → Appearance → Apps, and is never added twice.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfg: Quickshell.env("XDG_CONFIG_HOME") || `${root.home}/.config`

    function on(app) {
        return Config.get(`apps.theme.${app}`, false);
    }

    // Everything the files need, as #rrggbb.
    function hex(c) {
        const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return `#${h(c.r)}${h(c.g)}${h(c.b)}`;
    }

    // "#rrggbb" as a colour.
    function parse(hex) {
        const n = parseInt(String(hex).slice(1, 7), 16);
        return Qt.rgba(((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255, 1);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    /*
     * The colours every app file is written from. From matugen's scheme when
     * there is one (WallColours.scheme: the wallpaper's, or one built from your
     * accent), so surfaces, text and three accents belong together the way
     * Material You's do. Without matugen, the same roles are worked out from
     * the accent's hue: tinted greys, and secondary and tertiary turned from it.
     */
    readonly property var palette: {
        const dark = Theme.dark;
        const acc = Theme.accent;
        const role = (name, fallback) => {
            const v = WallColours.role(name);
            return v.length > 0 ? v : fallback;
        };
        const h = Math.max(0, acc.hslHue);
        const tone = (sat, light) => root.hex(Qt.hsla(h, sat, light, 1));
        const turn = (deg, sat, light) => root.hex(Qt.hsla((h + deg / 360 + 1) % 1, sat, light, 1));
        const L = dark ? [0.05, 0.07, 0.10, 0.13, 0.16] : [0.98, 0.95, 0.92, 0.89, 0.86];
        const p = {
            dark: dark,
            // Surfaces, from the deepest to the most raised.
            bgDeep: role("surface_container_lowest", tone(0.14, L[0])),
            bg: role("surface", tone(0.14, L[1])),
            bgAlt: role("surface_container", tone(0.14, L[2])),
            bgHi: role("surface_container_high", tone(0.14, L[3])),
            bgTop: role("surface_container_highest", tone(0.14, L[4])),
            fg: role("on_surface", tone(0.2, dark ? 0.92 : 0.12)),
            fgDim: role("on_surface_variant", tone(0.12, dark ? 0.72 : 0.32)),
            outline: role("outline", tone(0.1, dark ? 0.48 : 0.5)),
            accent: role("primary", root.hex(acc)),
            accentText: role("on_primary", (acc.r * 0.299 + acc.g * 0.587 + acc.b * 0.114) > 0.6 ? "#111111" : "#FFFFFF"),
            accentSoft: role("primary_container", tone(0.4, dark ? 0.25 : 0.85)),
            secondary: role("secondary", turn(30, 0.45, dark ? 0.75 : 0.4)),
            tertiary: role("tertiary", turn(60, 0.55, dark ? 0.78 : 0.4)),
            error: role("error", dark ? "#F2B8B5" : "#B3261E")
        };
        // Terminal hues, pulled a little toward the accent so they sit with it,
        // at one lightness and saturation so none shouts.
        // How far toward the accent (Config apps.terminalTint, 0 to 1): half
        // way by default, so a diff's greens and reds still read as such but
        // belong with the rest instead of being the stock green.
        const tint = Config.get("apps.terminalTint", 0.5);
        const pull = hue => {
            let d = h * 360 - hue;
            d = ((d + 540) % 360) - 180;
            return ((hue + d * tint) + 360) % 360 / 360;
        };
        /*
         * Terminal colours as roles, the way Material You terminal themes do it:
         * blue, magenta and cyan are the scheme's three accents, red its error
         * colour, and green and yellow soft pastels leaned toward the accent.
         * All sit at one softness, so a diff, a prompt and an ls listing look
         * like one thing rather than the stock eight hues on a tinted grey.
         */
        const soft = hue => root.hex(Qt.hsla(pull(hue), dark ? 0.48 : 0.5, dark ? 0.76 : 0.36, 1));
        const lift = c => root.hex(dark ? root.mix(root.parse(c), Qt.rgba(1, 1, 1, 1), 0.18) : root.mix(root.parse(c), Qt.rgba(0, 0, 0, 1), 0.15));
        p.hues = [p.error, soft(135), soft(48), p.accent, p.tertiary, p.secondary];
        p.brights = p.hues.map(lift);
        p.black = dark ? p.bgTop : p.fgDim;
        p.white = dark ? p.fgDim : p.bgTop;
        // Comments and dim text: readable, not a smudge.
        p.grey = root.hex(dark ? root.mix(root.parse(p.outline), root.parse(p.fg), 0.25) : root.parse(p.outline));
        return p;
    }

    onPaletteChanged: writeLater.restart()
    Component.onCompleted: writeLater.restart()

    Timer {
        id: writeLater

        // Dragging the hue strip changes the accent many times a second.
        interval: 900
        onTriggered: root.writeAll()
    }

    function writeAll() {
        const p = root.palette;
        if (root.on("terminal")) {
            root.put(`${root.cfg}/kitty/stratum.conf`, root.kitty(p));
            root.put(`${root.cfg}/alacritty/stratum.toml`, root.alacritty(p));
            root.put(`${root.cfg}/foot/stratum.ini`, root.foot(p));
            root.put(`${root.cfg}/ghostty/themes/stratum`, root.ghostty(p));
        }
        if (root.on("gtk")) {
            root.put(`${root.cfg}/gtk-3.0/stratum.css`, root.gtk(p));
            root.put(`${root.cfg}/gtk-4.0/stratum.css`, root.gtk(p));
        }
        if (root.on("spotify")) {
            root.put(`${root.cfg}/spicetify/Themes/Stratum/color.ini`, root.spicetify(p));
            root.put(`${root.cfg}/spicetify/Themes/Stratum/user.css`, "/* Stratum: colours only. */\n");
        }
        if (root.on("fetch"))
            root.put(`${root.cfg}/fastfetch/config.jsonc`, root.fetch(p));
        if (root.on("discord")) {
            for (const dir of ["vesktop", "Vencord", "equibop"])
                root.put(`${root.cfg}/${dir}/themes/stratum.theme.css`, root.discord(p));
        }
        hook.restart();
    }

    // Written by a script so missing folders are made, and only where the app
    // is set up at all (no ~/.config/foot appears for someone without foot).
    property var pending: []

    function put(path, text) {
        root.pending = [...root.pending, { path: path, text: text }];
    }

    Timer {
        id: hook

        interval: 10
        onTriggered: {
            const files = root.pending;
            root.pending = [];
            if (files.length === 0)
                return;
            const args = [];
            for (const f of files)
                args.push(f.path, f.text);
            writer.command = ["sh", "-c", `
                while [ $# -gt 1 ]; do
                    path="$1"; text="$2"; shift 2
                    base="\${XDG_CONFIG_HOME:-$HOME/.config}"
                    app="\${path#"$base"/}"; app="\${app%%/*}"
                    [ -d "$base/$app" ] || continue
                    mkdir -p "$(dirname "$path")" && printf '%s' "$text" > "$path"
                done
                # Tell what can be told to reload.
                pkill -USR1 -x kitty 2>/dev/null
                pkill -USR2 -x ghostty 2>/dev/null
                true`, "sh", ...args];
            writer.running = true;
        }
    }

    Process {
        id: writer

        onExited: {
            if (root.on("spotify") && root.spotifyApplied)
                spice.running = true;
        }
    }

    // Spicetify reads the theme when Spotify starts; refresh without restarting it.
    property bool spotifyApplied: Config.get("apps.theme.spotifyApplied", false)

    Process {
        id: spice

        command: ["sh", "-c", "command -v spicetify >/dev/null && spicetify refresh -s >/dev/null 2>&1; true"]
    }

    /*
     * Hooks an app up the first time it is switched on: the one line that loads
     * Stratum's file, at the end of its config, if it is not there already.
     */
    function connect(app) {
        Config.set(`apps.theme.${app}`, true);
        const c = root.cfg;
        const lines = {
            terminal: [
                [`${c}/kitty/kitty.conf`, "include stratum.conf"],
                [`${c}/foot/foot.ini`, "include=~/.config/foot/stratum.ini"],
                [`${c}/ghostty/config`, "theme = stratum"]
            ],
            gtk: [
                [`${c}/gtk-3.0/gtk.css`, "@import 'stratum.css';"],
                [`${c}/gtk-4.0/gtk.css`, "@import 'stratum.css';"]
            ]
        }[app] ?? [];
        const args = [];
        for (const [file, line] of lines)
            args.push(file, line);
        linker.command = ["sh", "-c", `
            while [ $# -gt 1 ]; do
                file="$1"; line="$2"; shift 2
                [ -d "$(dirname "$file")" ] || continue
                grep -qxF "$line" "$file" 2>/dev/null || printf '\\n# Stratum colours\\n%s\\n' "$line" >> "$file"
            done
            # The comment character differs for CSS: tidy it.
            for f in "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"; do
                [ -f "$f" ] && sed -i 's|^# Stratum colours$|/* Stratum colours */|' "$f"
            done
            # Alacritty imports through a list; added only when it has none.
            a="\${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.toml"
            if [ "$APP" = terminal ] && [ -f "$a" ] && ! grep -q 'stratum.toml' "$a" && ! grep -q '^import' "$a"; then
                printf '\\n[general]\\nimport = ["~/.config/alacritty/stratum.toml"]\\n' >> "$a"
            fi
            true`, "sh", ...args];
        linker.environment = { APP: app };
        linker.running = true;
        if (app === "spotify")
            spicetifySetup.running = true;
        // fastfetch reads one config; yours is kept beside it, once.
        if (app === "fetch")
            Quickshell.execDetached(["sh", "-c", `d="${c}/fastfetch"; mkdir -p "$d"
                [ -f "$d/config.jsonc" ] && ! grep -q 'Written by Stratum' "$d/config.jsonc" && [ ! -f "$d/config.before-stratum.jsonc" ] \
                    && cp "$d/config.jsonc" "$d/config.before-stratum.jsonc"; true`]);
        writeLater.restart();
    }

    function disconnect(app) {
        Config.set(`apps.theme.${app}`, false);
        // Your own fastfetch config back, as it was.
        if (app === "fetch")
            Quickshell.execDetached(["sh", "-c", `d="${root.cfg}/fastfetch"
                [ -f "$d/config.before-stratum.jsonc" ] && mv "$d/config.before-stratum.jsonc" "$d/config.jsonc"; true`]);
    }

    Process {
        id: linker
    }

    // Spicetify: choose the theme and apply it once (this restarts Spotify).
    Process {
        id: spicetifySetup

        command: ["sh", "-c", "spicetify config current_theme Stratum color_scheme stratum inject_css 1 replace_colors 1 >/dev/null && spicetify apply >/dev/null 2>&1"]
        onExited: code => {
            if (code === 0)
                Config.set("apps.theme.spotifyApplied", true);
        }
    }

    // --- the files ------------------------------------------------------------

    function ansi(p) {
        const h = p.hues;
        const b = p.brights;
        return [p.black, h[0], h[1], h[2], h[3], h[4], h[5], p.white,
            p.grey, b[0], b[1], b[2], b[3], b[4], b[5], p.fg];
    }

    function kitty(p) {
        const a = root.ansi(p);
        return ["# Written by Stratum from the shell's colours. Changes are overwritten.",
            `background ${p.bg}`, `foreground ${p.fg}`,
            `cursor ${p.accent}`, `cursor_text_color ${p.bg}`,
            `selection_background ${p.accent}`, `selection_foreground ${p.accentText}`,
            `url_color ${p.accent}`, `active_border_color ${p.accent}`,
            `active_tab_background ${p.accent}`, `active_tab_foreground ${p.accentText}`,
            `inactive_tab_background ${p.bgAlt}`, `inactive_tab_foreground ${p.fgDim}`,
            ...a.map((c, i) => `color${i} ${c}`)].join("\n") + "\n";
    }

    function alacritty(p) {
        const a = root.ansi(p);
        const names = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"];
        return ["# Written by Stratum from the shell's colours. Changes are overwritten.",
            "[colors.primary]", `background = "${p.bg}"`, `foreground = "${p.fg}"`,
            "[colors.cursor]", `cursor = "${p.accent}"`, `text = "${p.bg}"`,
            "[colors.selection]", `background = "${p.accent}"`, `text = "${p.accentText}"`,
            "[colors.normal]", ...names.map((n, i) => `${n} = "${a[i]}"`),
            "[colors.bright]", ...names.map((n, i) => `${n} = "${a[i + 8]}"`)].join("\n") + "\n";
    }

    function foot(p) {
        const a = root.ansi(p).map(c => c.slice(1));
        return ["# Written by Stratum from the shell's colours. Changes are overwritten.",
            "[colors]", `background=${p.bg.slice(1)}`, `foreground=${p.fg.slice(1)}`,
            `cursor=${p.bg.slice(1)} ${p.accent.slice(1)}`,
            `selection-background=${p.accent.slice(1)}`, `selection-foreground=${p.accentText.slice(1)}`,
            ...a.slice(0, 8).map((c, i) => `regular${i}=${c}`),
            ...a.slice(8).map((c, i) => `bright${i}=${c}`)].join("\n") + "\n";
    }

    function ghostty(p) {
        const a = root.ansi(p);
        return [`background = ${p.bg}`, `foreground = ${p.fg}`, `cursor-color = ${p.accent}`,
            `selection-background = ${p.accent}`, `selection-foreground = ${p.accentText}`,
            ...a.map((c, i) => `palette = ${i}=${c}`)].join("\n") + "\n";
    }

    function gtk(p) {
        return ["/* Written by Stratum from the shell's colours. Changes are overwritten. */",
            `@define-color accent_color ${p.accent};`,
            `@define-color accent_bg_color ${p.accent};`,
            `@define-color accent_fg_color ${p.accentText};`,
            `@define-color theme_selected_bg_color ${p.accent};`,
            `@define-color theme_selected_fg_color ${p.accentText};`,
            ":root {", `  --accent-color: ${p.accent};`, `  --accent-bg-color: ${p.accent};`, `  --accent-fg-color: ${p.accentText};`, "}"].join("\n") + "\n";
    }

    /*
     * The terminal greeting: the bar's mark — a ring of dots round an accent
     * dot — beside a short, lowercase list, ending in the palette as a row of
     * dots. fastfetch takes colours as SGR codes, so each is a truecolour one.
     */
    function fetch(p) {
        const sgr = hex => {
            const n = parseInt(hex.slice(1, 7), 16);
            return `38;2;${(n >> 16) & 255};${(n >> 8) & 255};${n & 255}`;
        };
        const logo = [
            "     $2·  ·  ·  ·",
            "  $2·              ·",
            " $2·                ·",
            "$2·        $1●        $2·",
            " $2·                ·",
            "  $2·              ·",
            "     $2·  ·  ·  ·"
        ].join("\n");
        const key = (type, name, extra) => Object.assign({ type: type, key: name }, extra ?? {});
        return "// Written by Stratum from the shell's colours. Changes are overwritten;\n"
            + "// switch it off in Settings → Appearance → Apps to get your own back.\n"
            + JSON.stringify({
                $schema: "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
                logo: {
                    type: "data",
                    source: logo,
                    color: { "1": sgr(p.accent), "2": sgr(p.grey) },
                    padding: { top: 1, left: 2, right: 4 }
                },
                display: {
                    separator: "  ",
                    color: { keys: sgr(p.fgDim), title: sgr(p.accent), output: sgr(p.fg), separator: sgr(p.grey) },
                    key: { width: 9 }
                },
                modules: [
                    "break",
                    { type: "title", format: "{user-name}{#" + sgr(p.grey) + "} · {#" + sgr(p.accent) + "}{host-name}" },
                    { type: "custom", format: "{#" + sgr(p.grey) + "}· · · · · · · · · · · · · · · ·" },
                    key("os", "system"),
                    key("kernel", "kernel"),
                    key("uptime", "up"),
                    key("packages", "packages"),
                    key("shell", "shell"),
                    key("wm", "desktop", { format: "{pretty-name} · stratum" }),
                    key("memory", "memory"),
                    "break",
                    { type: "colors", symbol: "circle", paddingLeft: 0 }
                ]
            }, null, 2) + "\n";
    }

    function spicetify(p) {
        const x = c => c.slice(1);
        return ["; Written by Stratum from the shell's colours. Changes are overwritten.",
            "[stratum]",
            `text               = ${x(p.fg)}`,
            `subtext            = ${x(p.fgDim)}`,
            `main               = ${x(p.bg)}`,
            `main-elevated      = ${x(p.bgAlt)}`,
            `main-transition    = ${x(p.bg)}`,
            `highlight          = ${x(p.bgHi)}`,
            `highlight-elevated = ${x(p.bgTop)}`,
            `sidebar            = ${x(p.bgDeep)}`,
            `player             = ${x(p.bgDeep)}`,
            `card               = ${x(p.bgAlt)}`,
            `shadow             = 000000`,
            `selected-row       = ${x(p.fg)}`,
            `button             = ${x(p.accent)}`,
            `button-active      = ${x(p.secondary)}`,
            `button-secondary   = ${x(p.fgDim)}`,
            `button-disabled    = ${x(p.outline)}`,
            `tab-active         = ${x(p.bgHi)}`,
            `notification       = ${x(p.accentSoft)}`,
            `notification-error = ${x(p.error)}`,
            `misc               = ${x(p.outline)}`,
            `play-button        = ${x(p.accent)}`,
            `play-button-active = ${x(p.secondary)}`,
            `progress-fg        = ${x(p.accent)}`,
            `progress-bg        = ${x(p.bgTop)}`,
            `heart              = ${x(p.tertiary)}`,
            `pagelink-active    = ${x(p.fg)}`,
            `radio-btn-active   = ${x(p.accent)}`].join("\n") + "\n";
    }

    /*
     * Vesktop / Discord: the Midnight theme with our colours in its variables,
     * as Caelestia does — Midnight does the layout, this only says what colour
     * each part is. Its five steps of each accent are the accent mixed further
     * toward itself, as Midnight's own builds are.
     */
    function discord(p) {
        const steps = (name, c) => [1, 2, 3, 4, 5].map(i => `  --${name}-${i}: color-mix(in srgb, ${c}, black ${(i - 1) * 7}%);`);
        const rgb = c => `${parseInt(c.slice(1, 3), 16)}, ${parseInt(c.slice(3, 5), 16)}, ${parseInt(c.slice(5, 7), 16)}`;
        return ["/**",
            " * @name Stratum",
            " * @description Midnight, in the Stratum shell's colours. Written by Stratum; changes are overwritten.",
            " * @author refact0r (Midnight), Stratum",
            " */",
            '@import url("https://refact0r.github.io/midnight-discord/build/midnight.css");',
            "",
            "body {",
            "  --gap: 12px;",
            "  --border-thickness: 1px;",
            "  --top-bar-height: var(--gap);",
            "  --top-bar-button-position: titlebar;",
            "  --custom-window-controls: on;",
            "  --custom-dms-icon: off;",
            `  --bg-floating: ${p.bgDeep};`,
            "}",
            "",
            ":root {",
            "  --colors: on;",
            `  --text-0: ${p.accentText};`,
            `  --text-1: ${p.fg};`,
            `  --text-2: ${p.fg};`,
            `  --text-3: ${p.fg};`,
            `  --text-4: ${p.fgDim};`,
            `  --text-5: ${p.outline};`,
            `  --bg-1: ${p.bgTop};`,
            `  --bg-2: ${p.bgHi};`,
            `  --bg-3: ${p.bgDeep};`,
            `  --bg-4: ${p.bg};`,
            `  --hover: rgba(${rgb(p.fg)}, 0.08);`,
            `  --active: rgba(${rgb(p.fg)}, 0.1);`,
            `  --active-2: rgba(${rgb(p.fg)}, 0.2);`,
            `  --message-hover: rgba(${rgb(p.fg)}, 0.06);`,
            "  --accent-1: var(--blue-1);",
            "  --accent-2: var(--blue-2);",
            "  --accent-3: var(--blue-3);",
            "  --accent-4: var(--blue-4);",
            "  --accent-5: var(--blue-5);",
            `  --accent-new: ${p.error};`,
            "  --online: var(--green-2);",
            "  --dnd: var(--red-2);",
            "  --idle: var(--yellow-2);",
            "  --streaming: var(--purple-2);",
            "  --offline: var(--text-4);",
            `  --border-light: rgba(${rgb(p.outline)}, 0);`,
            `  --border: rgba(${rgb(p.outline)}, 0.25);`,
            `  --button-border: rgba(${rgb(p.outline)}, 0);`,
            // Midnight's "colours" are its scheme's, not literal hues, as in
            // Caelestia's: online, idle and the rest come out of the palette.
            ...steps("red", p.error),
            ...steps("green", p.secondary),
            ...steps("blue", p.accent),
            ...steps("yellow", root.hex(root.mix(root.parse(p.accent), Qt.rgba(1, 1, 1, 1), 0.6))),
            ...steps("purple", p.tertiary),
            "}"].join("\n") + "\n";
    }
}
