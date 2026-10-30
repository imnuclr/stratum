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

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    readonly property var palette: {
        const dark = Theme.dark;
        const bg = Theme.surface;
        const fg = Theme.fg;
        const acc = Theme.accent;
        // Terminal colours: the usual eight hues, softened to sit with the
        // greys, with the accent for the cursor, selection and links.
        const hues = dark
            ? ["#E5534B", "#57AB5A", "#C69026", "#539BF5", "#B083F0", "#39C5CF"]
            : ["#C9352D", "#2D8A3A", "#9A6700", "#0969DA", "#8250DF", "#1B7C83"];
        return {
            dark: dark,
            bg: root.hex(bg),
            bgAlt: root.hex(root.mix(bg, fg, 0.06)),
            bgHi: root.hex(root.mix(bg, fg, 0.12)),
            fg: root.hex(fg),
            fgDim: root.hex(Theme.fgDim),
            accent: root.hex(acc),
            accentText: (acc.r * 0.299 + acc.g * 0.587 + acc.b * 0.114) > 0.6 ? "#111111" : "#FFFFFF",
            black: root.hex(dark ? root.mix(bg, fg, 0.18) : root.mix(fg, bg, 0.1)),
            white: root.hex(dark ? fg : root.mix(fg, bg, 0.75)),
            grey: root.hex(Theme.fgFaint),
            hues: hues
        };
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
        writeLater.restart();
    }

    function disconnect(app) {
        Config.set(`apps.theme.${app}`, false);
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
        return [p.black, h[0], h[1], h[2], h[3], h[4], h[5], p.white,
            p.grey, h[0], h[1], h[2], h[3], h[4], h[5], p.fg];
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

    function spicetify(p) {
        const x = c => c.slice(1);
        return ["; Written by Stratum from the shell's colours. Changes are overwritten.",
            "[stratum]",
            `text               = ${x(p.fg)}`,
            `subtext            = ${x(p.fgDim)}`,
            `main               = ${x(p.bg)}`,
            `main-elevated      = ${x(p.bgAlt)}`,
            `highlight          = ${x(p.bgHi)}`,
            `highlight-elevated = ${x(p.bgHi)}`,
            `sidebar            = ${x(p.bg)}`,
            `player             = ${x(p.bg)}`,
            `card               = ${x(p.bgAlt)}`,
            `shadow             = 000000`,
            `selected-row       = ${x(p.fg)}`,
            `button             = ${x(p.accent)}`,
            `button-active      = ${x(p.accent)}`,
            `button-disabled    = ${x(p.grey)}`,
            `tab-active         = ${x(p.bgHi)}`,
            `notification       = ${x(p.accent)}`,
            `notification-error = ${x(p.hues[0])}`,
            `misc               = ${x(p.grey)}`].join("\n") + "\n";
    }

    function discord(p) {
        return ["/**",
            " * @name Stratum",
            " * @description The Stratum shell's colours. Written by Stratum; changes are overwritten.",
            " * @author Stratum",
            " */",
            ":root, .theme-dark, .theme-light, .visual-refresh {",
            `  --brand-500: ${p.accent};`,
            `  --brand-560: ${p.accent};`,
            `  --brand-experiment: ${p.accent};`,
            `  --control-brand-foreground: ${p.accent};`,
            `  --text-link: ${p.accent};`,
            `  --background-primary: ${p.bg};`,
            `  --background-secondary: ${p.bgAlt};`,
            `  --background-secondary-alt: ${p.bgAlt};`,
            `  --background-tertiary: ${p.bgHi};`,
            `  --background-floating: ${p.bgAlt};`,
            `  --background-base-lower: ${p.bg};`,
            `  --background-base-low: ${p.bgAlt};`,
            `  --background-surface-high: ${p.bgHi};`,
            `  --text-normal: ${p.fg};`,
            `  --text-muted: ${p.fgDim};`,
            `  --interactive-normal: ${p.fgDim};`,
            `  --interactive-active: ${p.fg};`,
            "}"].join("\n") + "\n";
    }
}
