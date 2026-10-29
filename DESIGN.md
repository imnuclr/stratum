# Stratum

A Wayland desktop shell for Hyprland. Built on Quickshell (QML).

> **str. 1** wallpaper + depth · **str. 2** widget canvas · **str. 3** bar + panels · **str. 4** overlays + lock

The name is the architecture: Stratum renders your desktop as discrete layers, and
the wallpaper's subject sits *in front of* your widgets rather than behind them.

---

## 1. Why build this

Target system (verified 2026-10-29):

| | |
|---|---|
| Compositor | Hyprland 0.56.2, Wayland |
| GPU | NVIDIA RTX 3070 (GA104) |
| Displays | `DP-2` 3440x1440@165 (primary, 0x0) · `HDMI-A-1` 1920x1080@75 (right, +811 y-offset) |
| Toolkit | Quickshell 0.3.1 (installed) |
| Current shell | fork of Caelestia — `~/Documents/Github/cykler-caelestia`, 398 QML files |

### What makes the current setup feel clunky

Read from the fork, not guessed. These are the specific failures Stratum is designed against:

1. **Overlapping panel concepts.** `dashboard/`, `sidebar/`, `utilities/`, `nexus/`, `notch/`,
   `drawers/` — six modules, ~8500 lines, all answering "show a panel." Each reimplements
   show/hide, anchoring, blur and focus. No single owner means inconsistent animation and
   the classic two-panels-open-both-grabbing-keyboard bug.
2. **Giant modules.** `modules/lock` is 2413 lines, `dashboard` 1612, `background` 1562.
   Nothing that large stays coherent.
3. **Subprocess parsing where a native API exists.** `services/Nmcli.qml` is **1831 lines**
   and `services/VPN.qml` **838** — all shelling out to `nmcli` and parsing text.
   Quickshell 0.3 ships `Quickshell.Networking` (NetworkManager-backed: `devices`,
   `connect`, `connectWithPsk`, `connectWithSettings`, `forget`, `connectivity`,
   `linkSpeed`) and `Quickshell.Bluetooth`. **~2700 lines you simply never write.**
4. **Eager startup.** `shell.qml` force-loads `Notifs`, `Players`, `Brightness`, `Weather`
   and `VPN` in `Component.onCompleted` specifically to dodge lazy-load jank. That is a
   symptom, not a fix — it moves the cost to every login.
5. **No ultrawide intent.** A bar designed for 16:9 anchors the clock at 1720px from the
   status cluster on a 3440px display. Everything in Stratum is per-monitor from line one.

### What to keep from it

- `WlSessionLock` + `Quickshell.Services.Pam` is the correct lock architecture (`modules/lock/Lock.qml`).
- The transparency-aware colour maths in `services/Colours.qml` (`alterColour`/`layer`) —
  luminance-compensated layering over a wallpaper is genuinely good and worth porting in spirit.
- `//@ pragma` env block in `shell.qml`: `QSG_RENDER_LOOP=threaded` and
  `QT_QUICK_FLICKABLE_WHEEL_DECELERATION` are hard-won. Keep them.
- The C++ plugin boundary pattern — but build it *only* when profiling demands it, not up front.

---

## 2. Design language

Primary reference: **Nothing OS**. Secondary: macOS System Settings (for the settings app only).

### Principles

1. **Monochrome, one accent.** Greyscale and inverted fill carry *all* structure.
   Red appears on the media transport and nowhere else by default — about one element
   per screen. Semantic colours exist in the tokens but stay unused until something
   is genuinely wrong.
2. **Hairlines, not shadows.** 1px borders at 8% white. Shadows exist only on floating sheets.
3. **Dots are the rendering primitive, not a typeface.** Gauges are dotted rings.
   Progress bars are rows of dots. Sparklines are dot fields. Album art is dithered
   into dots. Numerals use a dot-matrix face. This is the identity, and it is why
   six small components carry the entire look.
4. **State is inverted fill.** A white tile is on, a dark tile is off. No glows, no
   accent borders, no coloured rings. `Tile.active` owns this so no module reinvents it.
5. **Caps micro-labels.** Section labels are 10–11px, uppercase, +8% tracking, 55% opacity.
6. **Origin-anchored motion.** Panels grow out of the thing you clicked. Nothing fades in
   at screen centre.
7. **Everything on a grid.** 4px baseline, 8px gutters, uniform. Visible in widget edit mode.

### Tokens — `theme.json`

```jsonc
{
  "color": {
    "bg":          "#0A0A0B",   // wallpaper scrim
    "surface0":    "#121214",   // bar islands, panels
    "surface1":    "#1A1A1D",   // tiles
    "surface2":    "#232327",   // hover / pressed
    "line":        "#FFFFFF14", // 8% hairline
    "lineStrong":  "#FFFFFF24",
    "text":        "#F2F2F3",
    "textDim":     "#A1A1A6",
    "textFaint":   "#6E6E73",
    "accent":      "#D71921",   // Nothing red
    "ok":          "#4ADE80",
    "warn":        "#FBBF24",
    "crit":        "#EF4444"
  },
  "radius":  { "tile": 20, "sheet": 28, "inner": 12, "pill": 999 },
  "space":   [4, 8, 12, 16, 24, 32, 48],
  "blur":    { "sheet": 32, "lock": 48, "strength": 0.9 },
  "font": {
    "display": "Doto",            // dot-matrix, OFL, variable weight
    "ui":      "Geist Sans",      // neo-grotesk
    "mono":    "JetBrainsMono Nerd Font"   // already installed
  },
  "motion": {
    "micro": 120, "standard": 200, "sheet": 320, "ambient": 500,
    "enterEasing": [0.2, 0, 0, 1],
    "exitEasing":  [0.3, 0, 0.8, 0.15]
  }
}
```

### Type scale

| Role | Face | Size / weight | Use |
|---|---|---|---|
| `display.xl` | Doto | 120 / 600 | lock clock |
| `display.l` | Doto | 64 / 600 | dashboard clock |
| `display.m` | Doto | 32 / 500 | temps, percentages |
| `display.s` | Doto | 20 / 500 | bar clock, meter values |
| `title` | Geist | 16 / 500 | card headings |
| `body` | Geist | 13 / 400 | content |
| `label` | Geist | 10 / 500, +8% tracking, UPPER | section labels |

### Fonts — licensing note

No dot-matrix face is currently installed. **Doto** (Google Fonts, OFL, variable weight)
is a true dot-matrix face and is redistributable — vendor it into `assets/fonts/`.
Nothing's own *Ndot-55* is **not** licensed for redistribution; don't ship it in a public repo.
Install locally if you want it, and expose `font.display` so the swap is one config line.

### Signature elements

- **Dot reveal.** Dot-matrix numerals animate on change by staggering individual dots
  (~8ms apart) rather than cross-fading. Used on the clock, volume OSD and lock feedback.
- **Glyph strip.** A horizontal dot-matrix LED bar that reacts to audio — a Nothing Glyph
  homage. Lives as a widget, as a lock-screen accent, and optionally in the bar's centre island.
- **Dot-grid button.** The control-centre trigger is a 3x3 grid of dots, not a hamburger.

---

## 3. Architecture

### Layer stack

This is the whole idea. Layer order, bottom to top:

```
  wlr-layer-shell: background   wallpaper — blurred/dimmed backplate
  wlr-layer-shell: background   widget canvas  (clock, weather, stats, media...)
  wlr-layer-shell: bottom       wallpaper SUBJECT (alpha cutout, parallax)   <- depth
  ---------------------------------------------------------------- app windows
  wlr-layer-shell: top          bar islands, OSD, notification toasts
  wlr-layer-shell: overlay      sheets (dashboard, control centre, launcher)
  ext-session-lock              lock screen
```

The cutout layer between widgets and windows is what produces the depth effect in the
unixporn posts: your widgets sit *behind* the subject of the wallpaper.

### Repo layout

```
stratum/
  shell.qml                 # root; pragmas, roots, daemons. Target: <80 lines.
  config/
    Config.qml              # singleton; FileView-watched JSON -> reactive props
    Schema.json             # single source of truth for every option
    defaults/               # shell.json, theme.json, widgets.json shipped defaults
  theme/
    Theme.qml               # singleton: resolved tokens
    Palette.qml  Type.qml  Motion.qml
    presets/                # nothing-dark, nothing-light, mono, mac, wallpaper
  services/                 # HARD CAP 200 lines each
    Audio.qml Network.qml Bluetooth.qml Power.qml Media.qml
    Notifications.qml SysStats.qml Gpu.qml Weather.qml Hypr.qml
    Wallpaper.qml Idle.qml Time.qml Tray.qml
  components/               # primitives only, no business logic
    Sheet.qml Tile.qml Pill.qml Chip.qml DotText.qml Glass.qml
    Meter.qml Sparkline.qml Switch.qml Slider.qml Row.qml SectionLabel.qml
  modules/
    bar/  dashboard/  control/  widgets/  lock/
    settings/  launcher/  osd/  notifications/  wallpaper/
  shaders/                  # .frag + qsb build step
  cli/                      # stratumctl
  assets/fonts/
  docs/                     # this file, screenshots, widget authoring guide
```

### The eight rules

These exist to prevent the specific decay found in the current shell.

1. **300-line cap per QML file.** Enforced in CI. Services cap at 200.
2. **Services are read-only singletons plus explicit mutators.** A service never
   imports a module. A module never writes service state except through a named function.
3. **Every panel is a `Sheet`.** One component owns anchoring, blur, backdrop, focus grab,
   Esc, click-outside, and the enter/exit transition. Panels supply content only.
4. **One panel open at a time, centrally.** `Shell.openPanel` is a single string on one
   singleton. Opening B closes A with a proper cross-transition. No exceptions.
5. **Lazy by default, with one documented exception.** Only the bar and wallpaper are
   resident; every sheet is a `LazyLoader`. If a panel janks on first open, fix the panel
   rather than preloading it. The exception is IPC: a lazy singleton never registers its
   `IpcHandler`, which is the real reason Caelestia force-loads five singletons at
   startup. Stratum declares its handlers in `shell.qml` instead and lets them pull the
   singleton in on first call, so nothing is preloaded just to be reachable.
6. **Native API or nothing.** Before writing a subprocess parser, check Quickshell 0.3.
   Networking, Bluetooth, Mpris, Notifications, Pipewire, UPower, Polkit, Pam, Tray,
   Greetd are all native.
7. **Per-monitor from the start.** Every window takes `screen`. Every visual config key
   is overridable under `monitors["DP-2"]`. Never hardcode a dimension.
8. **Config is reactive.** Editing JSON updates the running shell. Only code changes
   need a reload.

### Startup budget

Target: **bar visible in <400ms**, full shell warm in <1.5s. Measured in CI with
`QSG_RENDER_LOOP=threaded`, on the real 3440x1440 display.

---

## 4. Config and customisation

`~/.config/stratum/`

| File | Owner | Contents |
|---|---|---|
| `shell.json` | you | behaviour: modules enabled, bar layout, keybinds, per-monitor overrides |
| `theme.json` | you | tokens: colour, radius, spacing, fonts, blur, motion |
| `widgets.json` | edit mode | widget canvas instances (machine-written, hand-editable) |
| `state.json` | shell | runtime state: DND, last volume, pins. Never hand-edit. |
| `user/` | you | **drop-in QML overrides** |
| `generated/` | matugen | wallpaper-derived palette, extended by `theme.json` |

### Drop-in overrides

Any file under `~/.config/stratum/user/` shadows the same path in the shell:

```
~/.config/stratum/user/components/Tile.qml      -> replaces the built-in Tile
~/.config/stratum/user/modules/widgets/MyThing.qml  -> new widget, no fork needed
```

Implemented with a resolver in the import path. This is the actual customisation story,
and almost no Quickshell shell offers it — people fork instead.

### Theming modes

```jsonc
// theme.json
{ "preset": "nothing-dark" }                       // ship 5 presets
{ "preset": "nothing-dark", "color": { "accent": "#00FF88" } }   // override tokens
{ "source": "wallpaper", "mode": "dark" }          // matugen-derived, auto on wallpaper change
```

`matugen` is **not currently installed** — needed for wallpaper-derived palettes.

### Per-monitor example

Your real setup, in config:

```jsonc
{
  "bar": { "layout": "thirds", "edge": "top", "height": 38 },
  "monitors": {
    "DP-2":      { "bar": { "layout": "thirds" }, "widgets": true  },
    "HDMI-A-1":  { "bar": { "layout": "edges", "height": 32,
                            "modules": { "tray": false } },
                   "widgets": false }
  }
}
```

`layout: "thirds"` anchors the three bar islands at 25% / 50% / 75% instead of
left/centre/right — the ultrawide fix.

---

## 5. Modules

### 5.1 Bar

Three **separate floating pill islands**, not one continuous bar. Low weight, monochrome,
8px gap, 10px screen margin, 38px tall.

```
 ┌───────────────────────┐    ┌──────────────────┐    ┌──────────────────────────┐
 │ ● ○ ○ ○   ▣ kitty     │    │  ⣿⣿:⣿⣿   wed 29  │    │ ⌃  ⏷ ▮ ᛒ ♪ ▰  ⠿        │
 └───────────────────────┘    └──────────────────┘    └──────────────────────────┘
   workspaces  active win        dot-matrix clock       tray net bt vol batt  grid
```

**Left island** — workspace dots (filled = occupied, ring = active, hairline = empty;
hover expands to window counts), then active-window app glyph + title, truncated with a fade.

**Centre island** — dot-matrix clock + lowercase date. Click → dashboard. Hover → next
calendar event slides in. Optional: replace date with the Glyph audio strip.

**Right island** — system tray collapsed behind a chevron (expands in place, no overflow
menu), then status glyphs: network / bluetooth / volume / battery. Battery shows a
dot-matrix percentage below 25%. Dot-grid button → control centre.

Interactions: scroll on volume glyph = volume; scroll on workspaces = switch; middle-click
battery = power profile cycle. Every island is independently hideable per monitor.

### 5.2 Dashboard

Click the clock. A **wide horizontal strip** that slides down from the top edge, divided
into categories by vertical hairline rules, with a small grab handle centred on its lower
edge. Everything on one page, no scrolling. About 1,900px wide on `DP-2`.

```
┌─ TIME ───────────┬─ CLOUDY ───────┬─ SYSTEM ──────────────┬─ NET · ENP5S0 ─┬─ MOZILLA ZEN ──────┐
│ SATURDAY         │  ░░░  ⣿⣿°      │   ⣿ ⣿ ⣿   ⣿ ⣿ ⣿   ⣿⣿  │  ↓(⣿) 2.4 MB/S │ ░░░░  Fine Night   │
│                  │  ░░░░          │  (  4 ) ( 64 ) ( 28 ) │  ↑(⣿) 120 KB/S │ ░░░░  Goreshit     │
│ ⣿⣿ : ⣿⣿          │ FEELS 9°·4 M/S │  CPU·43° MEM·14G GPU  │                │ ●●●●·········      │
│                  │                │                       │  ▪ ▪▪ ▪ ▪▪▪ ▪  │ 1:00        5:16   │
│ 24 OCT · WEEK 43 │ SUN MON TUE WED│ PROCESSES  CORES·1.5G  │  ▪▪ ▪ ▪▪▪ ▪ ▪  │                    │
│ ●●●●●●●●●○○○○○○  │  ░░  ░░  ░░  ░░│ qs      15% ▪ ▪▪ ▪     │  ▪ ▪▪▪ ▪ ▪▪ ▪  │    ⏮   (⏸)   ⏭     │
│ ☀ 08:01  ☾ 18:16 │ 15° 13° 18° 14°│ zen-bin 14% ▪▪ ▪ ▪▪    │                │        red         │
└──────────────────┴────────────────┴───────────────────────┴────────────────┴────────────────────┘
                                        ▁▁▁▁▁▁  grab handle
```

Five columns. Every gauge in it is a `DotRing`, every bar a `DotBar`, every graph a
`DotField`, and the album art is run through the ordered-dither shader — so the column
code is assembly, not drawing.

GPU occupies a first-class ring alongside CPU and memory, fed by a dedicated `Gpu.qml`
reading `nvidia-smi`.

### 5.3 Control centre

Click the dot-grid. **This is deliberately not the dashboard**: the dashboard shows
*information*, the control centre takes *actions*. Conflating the two is the single
biggest structural problem in the current shell.

372 wide, anchored to the right island, grows from it. Top to bottom:

- **Header** — dot-matrix clock, date, and two circular buttons: settings and session.
- **Two wide connection pills** — Wi-Fi and Bluetooth side by side, each with a circular
  icon badge, a name, and the connected SSID or device count beneath. The badge inverts
  with the tile: on a white (active) tile the badge goes black. A chevron **expands the
  tile in place**, growing the sheet downward into a network list with inline PSK entry.
  No page navigation, ever.
- **Eight circular toggles**, four across, two rows, each with a caps label *below* the
  circle: DND, Night, Airplane, Caffeine, Mic, Record, VPN, Theme. Active ones fill white.
- **Two pill sliders** — brightness and volume. The filled portion is solid white with a
  black icon riding in it; the remainder shows as dots, with the numeric value in
  dot-matrix at the far right. Dragging raises a floating value bubble.
  On multi-monitor, brightness becomes a stack of per-display sliders.
- **Power profiles** — a four-segment control, each segment a signal-bars glyph with an
  increasing number of filled bars: ULT / ECO / BAL / MAX, backed by
  `power-profiles-daemon`. The selected segment is a white pill.
- **Media card** — dithered art, title, artist, and transport with the one red button.
- **Notifications** — a `NOTIFICATIONS · n` header with `CLEAR ALL` opposite, then rows
  with a circular app badge, a caps `APP · WHEN` line, and the body beneath.

**Movable icons.** The toggle grid is config-driven, not hardcoded:

```jsonc
"controlCentre": {
  "toggles": ["dnd", "night", "airplane", "caffeine", "mic", "record", "vpn", "theme"]
}
```

Long-press any toggle to enter arrange mode: the circles lift slightly, drag reorders
them, and the new order writes back to `shell.json`. A palette of about twenty actions is
available, and `user/modules/toggles/` takes your own. The same applies to the dashboard's
`columns` array and the slider list.

### 5.4 Widget canvas

A background layer hosting draggable, snappable widgets.

**Grid units, not pixels.** 24 columns per monitor, square cells. A widget placed at
`{x:2, y:1, w:6, h:3}` survives a resolution change. This is why widgets.json is portable
between your two displays.

```jsonc
// widgets.json
{
  "monitors": {
    "DP-2": [
      { "type": "clock",   "x": 2,  "y": 2, "w": 7, "h": 3,
        "props": { "variant": "dotmatrix", "seconds": false } },
      { "type": "weather", "x": 2,  "y": 6, "w": 7, "h": 4 },
      { "type": "sysmon",  "x": 15, "y": 2, "w": 7, "h": 5,
        "props": { "metrics": ["cpu","gpu","ram"], "style": "ring" } },
      { "type": "glyph",   "x": 2,  "y": 18, "w": 20, "h": 1 }
    ]
  }
}
```

**Registry.** Each widget is a QML file declaring its own contract:

```qml
StratumWidget {
    name: "sysmon";  minW: 4;  minH: 2;  defaultW: 7;  defaultH: 5
    schema: ({ metrics: { type: "multi", options: ["cpu","gpu","ram","ssd","net","temp"] },
               style:   { type: "enum",  options: ["ring","bar","sparkline"] } })
    // ...content
}
```

Resolved by `type` string → file. Drop a file in `user/modules/widgets/` and it appears in
the picker. That's how you get "lots and lots of widgets" without maintaining them all yourself.

**Edit mode** — `stratumctl widgets edit`: canvas dims, grid appears, widgets get corner
handles, magnetic snapping to grid and to neighbours with alignment guides, right-click for
the schema-generated settings popover, `Esc` saves back to `widgets.json`.

**v1 widget set (18)**

| Category | Widgets |
|---|---|
| Time | dot-matrix clock, hairline analog, word clock, binary clock, world clocks row |
| Calendar | month grid, agenda list |
| Weather | current, hourly strip, 7-day |
| System | sysmon (ring/bar/sparkline × cpu/gpu/ram/ssd/net/temp), disk usage, fetch block, uptime |
| Media | now playing card, album-art bleed, **glyph** audio strip |
| Utility | sticky note, todo checklist, pomodoro, battery ring, photo frame, dot-matrix ticker |

### 5.5 Lock screen

`WlSessionLock` + `PamContext`. Covers everything you asked for.

```
                         ( wallpaper: blurred backplate + sharp subject )

   good evening, charlie                              ┌─ WEATHER ───────────┐
                                                      │  ⣿⣿°  ☁  18°/11°    │
   ⣿⣿ : ⣿⣿                                            └─────────────────────┘
                                                      ┌─ NOW PLAYING ───────┐
   wednesday 29 october                               │ ▣ Song — Artist     │
                                                      │ ━━━●──────  ⏮ ⏸ ⏭   │
                                                      └─────────────────────┘
          ╭─────────────────────────╮                 ┌─ POWER ─────────────┐
          │ ▣  charlie              │                 │  ⣿⣿%  AC  2h 40m    │
          ╰─────────────────────────╯                 └─────────────────────┘
          ╭─────────────────────────╮                 ┌─ SYSTEM ────────────┐
          │ • • • • • • •        ⏎  │                 │ CPU ▰▰▰▱ 22%  48°   │
          ╰─────────────────────────╯                 │ GPU ▰▰▱▱ 14%  41°   │
                                                      │ RAM ▰▰▰▰▱ 46%       │
                                                      └─────────────────────┘

   ─────────────────────────────────────────────────────────────────────────────
     ▣ discord  3        ▣ mail  1        ▣ steam  2          ( content hidden )
```

- **Greeting** — time-of-day aware, string list configurable in `shell.json`.
- **Clock** — `display.xl` dot-matrix, dot-reveal on each minute change.
- **Password** — pill field, dots appear with the dot-reveal animation. Wrong password:
  horizontal shake, field hairline goes accent-red, dot-matrix attempt counter.
  PAM `MaxTries` → field locks with a countdown.
- **Notification privacy** — per-app glyph and count **only**. No titles, no bodies, no
  previews, not even on hover. Tapping is inert while locked. Controlled by
  `lock.notifications: "count" | "app" | "none"` — never a mode that shows content.
- **Media controls work while locked** (transport only, no track metadata if
  `lock.media.hideMetadata` is set).
- **Depth applies here too** — the subject cutout renders in front of the blurred plate
  and behind the cards, which is what makes these lock screens look good.

Security notes: the compositor refuses screencopy while locked (confirmed in the current
fork's comments — keep that assumption). Fail closed: if PAM errors, stay locked. Bind
`stratum ipc call lock lock` rather than invoking a binary.

### 5.6 Settings app

macOS System Settings, as you asked — and **schema-driven**, which is what stops a
settings app from rotting.

A real floating window (`FloatingWindow`), not a layer-shell panel, so it tiles like an app.

```
┌──────────────────────────────────────────────────────────────┐
│ ⊙  Stratum Settings                                    – ◻ ✕ │
├────────────────────┬─────────────────────────────────────────┤
│  ⌕ search          │   Appearance                            │
│                    │                                         │
│  ◐ Appearance      │  ┌─────────────────────────────────────┐│
│  ▭ Bar             │  │ Preset            nothing-dark   ⏷ ││
│  ⊞ Widgets         │  │ Mode              Dark           ⏷ ││
│  ⊙ Control Centre  │  │ Accent            ■ #D71921        ││
│  ⚿ Lock Screen     │  │ From wallpaper    ◯━               ││
│  ▤ Notifications   │  └─────────────────────────────────────┘│
│  ⌨ Shortcuts       │  ┌─────────────────────────────────────┐│
│  ▣ Displays        │  │ Corner radius     ──●────  20px     ││
│  ⚙ Services        │  │ Blur              ────●──  32       ││
│  ⓘ About           │  │ Transparency      ──●────  0.85     ││
│                    │  └─────────────────────────────────────┘│
│                    │                       Revert  Defaults  │
└────────────────────┴─────────────────────────────────────────┘
```

- Grouped hairline cards, `label ...... control` rows. That's the whole macOS pattern.
- **Every control is generated from `config/Schema.json`.** Adding an option is one schema
  entry, not new UI code. Types: `bool`, `int`, `real`, `enum`, `multi`, `color`, `font`,
  `path`, `string`, `keybind`, `monitorMap`.
- **Live preview** — same process, so a write to the config singleton updates the real
  shell instantly. No apply button.
- **Displays** section reads `hyprctl monitors` and assigns bar layout / widget set /
  wallpaper per output.
- **Shortcuts** section: your Hyprland config is Lua-generated (`~/.config/hypr/*.lua`),
  so Stratum must **never rewrite it**. Write to `~/.config/stratum/generated/binds.conf`
  and have the user add one `source =` line. Non-destructive by construction.

### 5.7 Supporting modules

- **OSD** — volume / brightness / mic, a single pill at the screen edge with a dot-matrix
  value. Shared component, three consumers.
- **Notifications** — toasts top-right, stacked with a count collapse, swipe to dismiss,
  per-app grouping, inline actions, DND respected. Native `Quickshell.Services.Notifications`.
- **Launcher** — one search field, fuzzy app search, plus prefixed modes: `>` shell,
  `=` calculator, `?` web, `:` emoji, `/` file. Results as hairline rows. No grid of icons.
- **Wallpaper** — own layer-shell surface. Crossfade and wipe transitions, per-monitor
  images, optional rotation on a timer. Replaces swww (not installed, not needed).

---

## 6. The depth effect

Two approaches. Ship **A** first; it reads far stronger and is ~40 lines.

### A. Cutout parallax (recommended)

Split the wallpaper into backplate + subject PNG with alpha. The subject renders on the
`bottom` layer, above the widget canvas. Widgets are physically behind the subject.

- Cutout generated once per wallpaper by a helper (`rembg` / `backgroundremover`),
  cached to `~/.cache/stratum/cutout/<hash>.png`. Hand-made cutouts drop in and win.
- Mouse position and workspace index drive a few px of offset — subject moves ~6px,
  backplate ~2px, opposite directions. Spring-damped, not linear.
- Backplate gets a slight blur and desaturation so the subject pops.
- Degrades perfectly: no cutout found → flat wallpaper, no visual bug.

### B. Depth-map displacement shader

A `ShaderEffect` with a `.frag` (compiled by `qsb`; `glslangValidator` is already present)
that displaces UVs by a depth map and applies depth-of-field blur. Gives fake 3D parallax
from a single image.

- Depth map from MiDaS via a small Python helper, cached in `~/.cache/stratum/depth/`.
- Free on a 3070. Subtler than A — best used *together* with A on the backplate.

---

## 7. Services

One concern each, 200-line cap, native API wherever one exists.

| Service | Backing | Notes |
|---|---|---|
| `Audio` | `Quickshell.Services.Pipewire` | sinks, sources, per-app volume, default device |
| `Network` | **`Quickshell.Networking`** | native NM. Replaces 1831 lines of nmcli parsing |
| `Bluetooth` | **`Quickshell.Bluetooth`** | native. Pairing, device battery |
| `Power` | `Quickshell.Services.UPower` + `power-profiles-daemon` | battery, AC, profiles |
| `Media` | `Quickshell.Services.Mpris` | native — `playerctl` not required |
| `Notifications` | `Quickshell.Services.Notifications` | native server |
| `Tray` | `Quickshell.Services.SystemTray` | + `DBusMenu` |
| `SysStats` | `/proc`, `lm_sensors` | ring buffer history for sparklines |
| `Gpu` | `nvidia-smi -q -x` | util, VRAM, temp, power. First-class on this box |
| `Weather` | open-meteo (no API key) | cached, 15-min refresh, geoclue or fixed coords |
| `Hypr` | `Quickshell.Hyprland` | workspaces, clients, monitors, IPC events |
| `Idle` | `Quickshell.Wayland` idle-notify | lock timer, dim, inhibit |
| `Wallpaper` | own | current image, cutout/depth cache, transitions |

Also available and worth using: `Quickshell.Services.Polkit` (in-shell auth prompts),
`Quickshell.Services.Greetd` (if you later want a matching login greeter).

---

## 8. Living alongside other shells

Stratum installs as a sibling Quickshell config, never a replacement. Caelestia stays at
`~/.config/quickshell/caelestia`; Stratum links in beside it. `shellctl` decides which one
owns the session, persisting the choice to `~/.config/stratum/active-shell` so the
Hyprland autostart reads it rather than hardcoding a shell.

```sh
shellctl              # picker, fzf when available
shellctl list         # installed shells, and which is running
shellctl use stratum
shellctl restart
```

One caveat worth recording: `pkill -f "qs -c stratum"` matches the *calling* script's own
command line, so a naive switcher kills its own shell session. `shellctl` enumerates with
`pgrep -f` and filters its own pid and parent before killing anything.

## 9. CLI and IPC

`stratumctl` — thin wrapper over Quickshell IPC.

```sh
stratumctl toggle dashboard|control|launcher
stratumctl lock
stratumctl widgets edit
stratumctl wallpaper set <path>
stratumctl theme set nothing-light
stratumctl reload
```

Keybinds call it, which keeps Hyprland config stable across refactors.

---

## 10. Roadmap

Deliberately ordered so something looks good on screen at the end of every phase.

| Phase | Scope | Exit criterion |
|---|---|---|
| **0 — Skeleton** | repo, `shell.qml`, `Config` + `Theme` with live reload, `Sheet`/`Tile`/`Pill`/`DotText`, fonts vendored | a floating pill shows the real clock in Doto, and editing `theme.json` changes it without a reload |
| **0 — done** | verified on the real hardware: bar renders on both monitors, Doto clock live, per-monitor height override applied, config and theme hot-reload from JSON, `panel` IPC round-trips | &check; |
| **1 — Bar** | three islands, workspaces, active window, tray, status cluster, per-monitor, `thirds` layout | daily-drivable bar on both displays |
| **2 — Services** | SysStats, Media, Netstat, Weather &mdash; done. Notifications and Gpu remain | every number in the dashboard is real |
| **3 — Dashboard + Control** | both sheets built. In-place tile expansion remains | you stop opening the old shell |
| **4 — Wallpaper + depth** | wallpaper layer, cutout parallax, depth shader, transitions | the subject sits in front of a widget |
| **5 — Widget canvas** | registry, grid, edit mode, first 8 widgets | you can lay out a desktop with the mouse |
| **6 — Lock** | `WlSessionLock`, PAM, all cards, privacy notifications | you trust it enough to bind it |
| **7 — Settings** | schema-driven, all 9 sections | you configure Stratum without opening a text editor |
| **8 — Polish** | OSD, launcher, toasts, remaining 10 widgets, `stratumctl`, install script, README + screenshots | public repo |

Rough pace at a few hours a day: phases 0–2 in week one, 3–4 in week two, 5–6 in week
three, 7–8 in week four.

---

## 11. Dependencies

**Already present:** quickshell-git 0.3.1, hyprland, qt6-declarative, qt6-5compat, gtk4,
libadwaita, pipewire + wireplumber, networkmanager, bluez, upower,
power-profiles-daemon, brightnessctl, lm_sensors, libcava, grim, slurp, wl-clipboard,
cmake, ninja, gcc, glslangValidator, qmlformat, qmllint, JetBrainsMono Nerd Font.

**To install**

| Package | For | Required? |
|---|---|---|
| `matugen` | wallpaper-derived palettes | only for `source: "wallpaper"` |
| `qt6-shadertools` | `qsb` shader compilation | yes, for the depth shader |
| `python-rembg` *(or AUR `backgroundremover`)* | automatic wallpaper cutouts | optional — hand cutouts work |
| `ttf-doto` *(or vendor the OFL file)* | dot-matrix display face | yes |
| `otf-geist` *(AUR)* | UI face | substitutable with Inter |

**Explicitly not needed:** `playerctl` (Mpris is native), `swww`/`hyprpaper` (own wallpaper
layer), `cava` binary (libcava + Pipewire FFT), `nmcli` wrappers (Networking is native).

---

## 12. Open questions

1. **Accent** — fixed Nothing red `#D71921` as the default, or wallpaper-derived out of
   the box? Red is more distinctive; derived is more versatile.
2. **Bar edge** — top (assumed) or bottom? Nothing's own taskbar sits at the bottom.
3. **Widget home** — widgets on the ultrawide only (assumed), or both displays?
4. **Greeter** — lock screen only, or a matching greetd login screen later?
5. **Ndot** — vendor Doto (safe, OFL) and let you swap locally, or do you want the real
   Ndot wired up for private use?

---

## 13. Verified on hardware

Findings from running Phase 0 on the target machine, kept because each one cost time:

1. **Lazy singletons do not register IPC.** An `IpcHandler` inside a `pragma Singleton`
   is never reachable until something references the singleton. Declare handlers in
   `shell.qml`.
2. **Do not hand-write `qmldir` files.** Quickshell generates the `qs.*` modules from the
   directory tree; a hand-written `qmldir` is at best redundant. Caelestia has none.
3. **Floating surfaces need a stronger hairline than nested ones.** At 7% white over a
   dark wallpaper the bar was invisible in a screenshot. `Tile.floating` raises the border
   to 14% for anything that sits directly over the wallpaper.
4. **`pkill -f` matches the caller.** See §8.
5. **A new directory needs a full restart, not a hot reload.** Quickshell builds the
   `qs.*` module map when the config loads, so adding `modules/dashboard/` and importing
   it silently produced no delegates and logged nothing at all — `Variants` just yielded
   nothing. `qs -c stratum kill` then relaunch. Editing files inside an existing
   directory hot-reloads normally.
6. **Exclusive keyboard focus on a layer surface logs Qt noise.** A `Sheet` taking
   `WlrKeyboardFocus.Exclusive` with no text input in it emits repeated
   `QWaylandTextInputv3::disableSurface ... but 0x0 is focused` warnings. Harmless, and
   not worth suppressing globally — just don't mistake it for a real fault.
7. **`Quickshell.Networking` has two undocumented shapes.** `Network.signalStrength` is
   **0..1, not 0..100** — feeding it to a 0..100 threshold silently selects the weakest
   icon. And `NetworkDevice.network` stays null even on a connected wifi device; the
   active network is the connected entry in `device.networks`. The backend also
   populates asynchronously, so for roughly the first second `devices` is empty and
   `wifiEnabled` reads false. Bind to it; never read it in `Component.onCompleted`.
8. **Don't swap between strength-variant glyphs.** The weakest wifi variant is a lone
   dot, which at 16px reads as "no icon" rather than "weak signal". `WifiGlyph` stacks
   all four arcs and dims the unlit ones instead, so the shape is always present.
9. **`font.pixelSize` is an int.** Assigning a real (`12.5`) doesn't warn — it fails the
   whole config load with "Invalid property assignment". `DotText` rounds at the
   assignment so callers can pass a real `size`.
10. **An anchored child inside a `Grid` silently disables the layout.** Putting a
   `MouseArea { anchors.fill: parent }` in a `Grid` logs "Grid will not function" and
   stacks every cell at the origin. Wrap the Grid in an Item and make the hit area a
   sibling.
11. **Hyprland's Lua config mode changes dispatch entirely.** When Hyprland runs a Lua
   config (`Hyprland.usingLua`), the IPC dispatch argument is evaluated as Lua, so
   `workspace 2` fails with "attempt to call a nil value" and no plain-string form
   works. The equivalent is `hl.dsp.focus({ workspace = "2" })`. This silently broke
   workspace clicking and scrolling until it was tested through the real code path.
   Caelestia branches on `usingLua` at eight separate call sites; `services/Hypr.qml`
   keeps the split in one place and gives modules semantic functions instead.
12. **A wrong QML enum member is `undefined`, not an error.** `WifiSecurityType` has
   members `Open`, `Owe`, `StaticWep`, `DynamicWep`, `Leap`, `WpaPsk`, `Wpa2Psk`,
   `Wpa2Eap`, `WpaEap`, `Sae`, `Wpa3SuiteB192`, `Unknown` — not the `None`/`Wpa2`/`Wpa3`
   you would guess. A `switch` over invented members compiles, warns about nothing, and
   silently takes the default branch. Read the enum, don't assume it.
13. **`NetworkDevice.address` is the MAC, not the IPv4 address**, and the module doesn't
   expose IPv4 at all. `Network.ipv4` reads it from `ip -4 -json` — the only place that
   service leaves the native API, and only because there is no alternative.
14. **A positioner's `implicitWidth` is read-only.** Assigning it on a `Column` warns
   "Invalid property assignment" at runtime and the popouts rendered unsized. Wrap the
   column in an `Item` that owns the width and report the height back up.
15. **A bare `Text` ignores its frame.** Hint lines in the popouts were the widest
   element and drew straight past the panel edge, since nothing constrains a Text
   without an explicit `width`. Set `width` and `wrapMode` on anything that can outgrow
   its container.
16. **Qt silently discards a malformed bezier curve and animates linearly.**
   `easing.bezierCurve` must be a multiple of six reals — two control points plus
   the end point `(1,1)` per cubic segment. The tokens were written as four
   (`[0.2, 0, 0, 1]`), which Qt stores as `[]`, logs nothing about, and falls back
   to linear for. Every animation in the shell was linear for its first few
   commits, which is exactly how it looked. Verified by reading
   `easing.bezierCurve` back off a `NumberAnimation` at runtime.
17. **`Quickshell.Networking` exports a type called `Network`.** Importing that
   module into a file that uses the `Network` service singleton shadows the
   singleton, and every read comes back `undefined` with no warning — the wifi
   popout rendered "Wi-Fi is off" over a live connection. This is the same trap
   that `Bt` is named around. Files that use the service must not import the
   module; type model entries as `var` instead. `Quickshell.Bluetooth` and
   `Quickshell.Services.Pipewire` export nothing that collides with `Bt` or
   `Audio`, so only this one needs the rule.
18. **A self-referential binding spins the render thread.** Writing
   `source: { ... default: return loader.source }` to hold a Loader's previous
   content pegged the process at 42% CPU with no binding-loop warning. The
   "keep the last value" state belongs in the service (`Popouts.content`), not in
   a binding that reads the property it sets.
19. **A shared Loader keeps its last content mounted,** so `Component.onDestruction`
   never runs for it. The wifi scanner was enabled on the network popout's
   `onCompleted` and never disabled, leaving the radio scanning for the rest of
   the session. Lifecycle side effects in shared-surface content must bind to
   whether that content is *shown*, not to the component's lifetime.
20. **Popouts cannot live in their own layer surface while another shell is
   running.** A surface with `ExclusionMode.Ignore` spans the whole output, while
   the bar respects other shells' exclusive zones and so starts 60px in here. The
   two had different origins, nothing in the API reports a layer surface's
   position, and the left/right split of the inset can't be derived from widths.
   Hosting the popout inside the bar window makes the trigger's coordinates and
   the popout's the same coordinates by construction, and lets one `mask` keep the
   area below the bar click-through.
21. **The auto exclusive zone double-counted the margin.** Letting Quickshell
   derive it reserved 78px on DP-2 for a 38px bar at a 10px margin; setting
   `exclusiveZone: barHeight + margin` explicitly reserves 68, which is the bar
   plus one margin, and moves the bar to where `bar.margin` says it should be.
22. **A "remember the last value" property must be seeded, not left empty.**
   `Popouts.content` held the last popout name so the frame could finish its close
   transition, but it was only assigned in `onCurrentChanged` — so a popout open
   across a config reload rendered an empty frame. Initialising it from `current`
   gives the right value and the first assignment replaces the binding.
23. **Qt can deliver a new item's `onEntered` before the old item's `onExited`.**
   Hover popouts that decide to close from the most recent leave event therefore
   close the popout that was just opened — moving between the network, bluetooth
   and audio glyphs made each menu appear and immediately shut. `Popouts` counts
   hover sources instead, including the panel body, so the outcome does not depend
   on delivery order. Reproduced directly by calling show/show/release in that
   order over IPC.
24. **An overshooting easing curve must not be run in reverse.** The tray used the
   expressive curve in both directions; played backwards its overshoot becomes an
   undershoot that returns to the target at the very end, which reads as a snap
   after an otherwise smooth close. Opening keeps the overshoot, closing uses the
   exit curve, selected on `expanded` inside the Behavior.
25. **Position and size must not animate on first appearance.** The popout frame
   animates x, width and height so it can travel between triggers, but on its
   first open those animated from the clamped default — the panel slid in from the
   left edge of the screen and grew out of the placeholder content size. The
   Behaviors are gated on the frame already being visible, so the first open jumps
   to position and only later moves animate.
26. **A panel whose frame animates to fit its content must clip.** Content is laid
   out at full size while the frame is still resizing, so the audio popout's
   headings rendered outside the panel for a few frames. Clipping plus anchoring
   the content to the top, rather than centring it, keeps a height change growing
   downwards instead of pushing content out of both ends.
27. **Tray icons arrive in three shapes, one of them broken.** Items hand over a
   themed icon name, a pixmap (`image://qspixmap/...`), or an absolute file path
   pushed through the themed-icon provider as `image://icon//usr/...`. The last
   resolves to nothing and leaves a silent empty slot that reads as a gap in the
   pill — `Icons.trayIcon` rewrites it to a `file://` URL, and anything that still
   fails falls back to a glyph rather than rendering nothing. Pixmaps also need
   `sourceSize` at the drawn size; upscaling a 16px pixmap to 34px turns it to mush.
28. **A child `MouseArea` with `hoverEnabled` takes hover from its parent** and
   fires the parent's `onExited` as it does. Every switch, radio and button inside
   a popout therefore read as the pointer leaving the panel, and it closed as soon
   as you stopped moving or went to click something. A `HoverHandler` stays
   hovered while the pointer is over a child, and because it exposes hover as
   bound state rather than as events, the close decision no longer depends on
   which event arrived last. The window `mask` has to cover the gap between the
   bar and the panel too: input outside the mask never reaches the client, so a
   HoverHandler `margin` over unmasked space does nothing.
29. **Assigning `x` to a positioner's child fights the positioner, silently.** The
   tray's reveal slid each icon by binding `x`, which a `Row` also owns — so every
   icon stacked at the same place and they rendered on top of one another. Only
   *anchors* inside a positioner produce the "Cannot specify anchors for items
   inside Row" warning; writing `x` or `y` just loses. A per-child offset inside a
   positioner belongs in a `transform: Translate`, which is what the animation
   uses now.
30. **One `Binding` per monitor writing the same singleton property fight each
   other.** `Variants` builds a popout per screen, so both were driving
   `Popouts.surfaceHovered` and the screen with nothing hovered clamped it to
   false. Shared state written from a per-monitor component needs a `when` guard
   naming the monitor that owns it.
31. **A clipping container must not resize while its contents are animating.** The
   tray snapped at both ends. Opening, the clip edge uncovered icons faster than
   they could fade in; closing, the container reached zero width at 200ms while
   the last icons were still fading until 240ms, so they were chopped off
   mid-fade — which is exactly the "snaps in at the last moment" in the recording.
   The two phases are now sequenced: open widens the container and then staggers
   the icons in, close clears the icons and only then collapses the container, so
   the clip edge never crosses a visible icon. A decelerating curve on the width
   also front-loads the change into the first third and reads as a pop on its own,
   so size changes use an eased-both-ends curve instead.
32. **`DotText` is a `Row`, so it has no width to align within.** Giving it a
   `width` and `horizontalAlignment` is silently ignored, since a positioner
   sizes itself to its contents. Right-aligning a column of percentages means
   wrapping it in an `Item` of fixed width and anchoring the text inside.
33. **A history array has to be padded to its full length from the start.** A dot
   field takes one column per value, so an array that fills up sample by sample
   makes the field grow a column at a time, which reads as a layout bug rather
   than as a graph filling. The services seed theirs with zeros.
34. **A `Repeater` warns on a negative model, which a size-derived count
   produces for one frame.** `Math.floor(height / pitch)` is negative while the
   parent has not laid out and the height is still a negative margin, giving
   "Model size of -7 is less than 0" on every instance. Clamp at zero.
35. **An item that sizes itself from a child anchored back to it can collapse to
   zero.** A status item bound `height` to its content Column's implicitHeight
   while that Column was `anchors.centerIn` the item. Nothing warns, the glyphs
   still draw, and the item is left with no hover area at all. Size from the
   child directly, with a floor.
36. **`hyprctl dispatch global stratum:x` does nothing under a Lua config.**
   Dispatch arguments are evaluated as Lua, so the global dispatcher has to be
   called as `hyprctl dispatch "hl.dsp.global('stratum:x')"`. The plain form
   returns `ok` and fires nothing, which cost a round of chasing a shortcut that
   was registered and working.
37. **Hyprland keeps both bindings when a key is bound twice.** Binding a key
   already bound in keybinds.lua does not replace it — both fire, so a press
   takes two screenshots or moves the volume twice. `hl.unbind` has to drop the
   original first; it is guarded with `type(...) == "function"` since it is not
   in every version.
38. **The mask decides what the compositor delivers; an item decides what sees
   it.** Both are needed. The band bridging a sheet to the screen edge was in the
   mask but had no item in it, so input arrived at the surface and landed on
   nothing — and that band is exactly where the hot zone sits, which the sheet's
   mask covers the moment it opens. The trace showed the zone going false on the
   same frame the panel opened, no sheet hover at all, and the grace closing the
   panel under a stationary cursor. An item spanning the whole mask, holding
   nothing but the handler, fixes it; clicks and the controls' own hover pass
   through to the card beneath.
39. **A window that only exists while open has no settled layout when it opens.**
   The control centre's rect went 428x398 and then 428x704 across consecutive
   opens — the first before its content had measured itself. That moves the input
   mask under a stationary pointer, the compositor has to re-decide what the
   pointer is over, and the sheet jitters and closes. It showed only on the
   monitor whose sheet was opened least: every instance pays this once, and one
   that keeps closing never gets past it, so it looked like a property of the
   smaller screen. Keep the window mapped with an empty input region instead, so
   layout settles at launch and an open is a single region change.
40. **An animation that fights a fade is not read as motion.** A sheet rising 56px
   while fading in was described as arriving from the top, four times, because the
   travel was swamped by the opacity. The geometry was right the whole time —
   origin at the bottom corner, slide positive, rising. 255px of travel reads as a
   direction; 56 reads as materialising. Verified by logging the animated value
   rather than by looking: pixel-sampling a fading panel measures the fade, not
   the position, which sent two separate investigations the wrong way.
41. **A JavaScript array as a model also kills a drag.** A Repeater over an array
   rebuilds every delegate when the array is replaced, and a brightness slider
   replaced the array on each step of its own drag — so the delegate under the
   pointer was destroyed mid-gesture, taking the MouseArea's grab with it. The
   slider moved once per press and then went dead, while the volume slider, which
   is not in a Repeater, dragged perfectly. Same cause as the notifications not
   animating, two symptoms that looked nothing alike.
42. **ddcutil's model and the output's model are the same EDID field.** Matching a
   ddcutil display to a Hyprland output is not the guesswork an earlier note here
   claimed: "XG22VA" against HDMI-A-1, "34E6UC" against DP-2, read straight off
   both. Take it from `Quickshell.screens`, not from Hyprland's monitor object —
   that reports the model for one of these two outputs and not the other.
43. **A JavaScript array as a view's model resets it on every change.** A new
   array is a whole new model, so the view is never told that one row went — it
   is told to start again, and a reset destroys and rebuilds every delegate. No
   add, remove or displaced transition can run across one, and the rows simply
   blink from one arrangement to the next. It looks like the transitions were
   written wrong. Give a view the server's own object model and keep the array
   for counting and walking.
44. **Drive the pointer instead of asking.** Four rounds were spent on a hover
   fault that could not be reproduced by reading code, each one shipping a
   different theory. `hl.dsp.cursor.move` walked in small steps — 20ms apart,
   not teleported — reproduces a real approach well enough to watch a panel open,
   hold and close, and found the cause in one pass. A teleport is still no good
   for judging whether a hover path *feels* right, but for whether it fires at
   all it is decisive, and far better than another round-trip.
45. **A HoverHandler margin past the input mask makes hover oscillate.** The mask
   is what the compositor delivers pointer events into, so a handler claiming
   hover beyond it gets an enter it is immediately told to take back. Logging the
   pointer position in the handler showed it exactly: hovered going true then
   false at one unchanging position, inside the margin, with the pointer not
   moving at all. Reaching past the card is a job for the mask, which now bridges
   the gap between the sheet and the screen edge it came from — which is also
   where the hot zone lives, so travelling from the zone into the sheet crosses no
   dead ground. **Log the pointer position, not just the hover state:** three
   rounds of guessing at why hover dropped ended the moment the trace carried a
   coordinate.
46. **slurp blocks on stdin when stdin is a pipe.** It takes a list of candidate
   regions that way, so spawned from the shell — which hands a child a pipe — it
   never connected to Wayland and drew nothing: 0 open sockets, blocked in
   `anon_pipe_read`, alive for a quarter of an hour. From a terminal it worked
   perfectly, which is what made it look like a keybind fault for three rounds.
   `</dev/null` on every slurp. Check `/proc/<pid>/wchan` and the socket count
   before blaming the thing that launched a process.
47. **A sheet that cannot fit goes to the top.** Deriving y from the space left
   over and flooring it at zero places a too-tall sheet at `edgeGap`, so the
   control centre — momentarily taller than a 1080 screen while its content
   settles — appeared at the top and travelled down. A bottom-anchored sheet pins
   its bottom edge unconditionally. It never showed on the 1440 monitor, where it
   always fit, which is why it could not be reproduced from the desk it was
   reported on.
48. **`gpu-screen-recorder -w focused` demands `-s WxH`** and errors out without
   it, recording nothing at all. Naming the output (`-w DP-2`) gives its native
   resolution for free; `-w screen` picks whichever output it considers first,
   which is not the one being worked on.
49. **Hyprland's modmask has SHIFT at 1 and ALT at 8, not the other way round.**
   `SUPER + SHIFT` is 65; 72 is `SUPER + ALT`. Counting binds at mask 72 to decide
   who owned `SUPER + SHIFT + S` compared two different key combinations and
   produced a confident, wrong conclusion that `hl.unbind` cannot reclaim modified
   keys. It can: at mask 65 the unbind works and the surviving bind is ours. The
   actual screenshot fault was the latched busy flag below. Read the mask before
   trusting a bind count.
50. **A flag held for the lifetime of an external capture latches.** Screenshot
   guarded re-entry with a `busy` flag cleared on process exit. Anything that
   ended the capture without that exit left it set and every screenshot
   afterwards was dropped in silence — which is why restarting the shell appeared
   to fix the keybind. A guard against double-firing wants a timer, not a
   lifetime. Dropping `Print` worked;
   `SUPER + SHIFT + S` could not be dropped in any spelling, so caelestia kept it
   and Hyprland silently discarded the duplicate — the shortcut was registered,
   the bind existed, and the key still did nothing. Proving which config owned a
   key meant removing one side and counting binds again. Screenshot actions moved
   to `Print`, `SUPER + Print` and `CTRL + Print`; `SHIFT + Print` is not usable
   because that combination emits SysRq rather than Print.
51. **A transform moves what is drawn but not where input lands.** Sliding a sheet
   in with `transform: Translate` left the picture and the pointer disagreeing for
   the length of the animation, and hover-opened panels flapped open and shut.
   Animating the item's own `y` keeps the mask with it.
52. **Warping the cursor is not a substitute for hovering** — and after changing
   an item's size, recompute where it actually is before concluding a hover is
   broken. Two rounds were spent on a popout that was opening correctly the whole
   time, off the edge of the crop being captured.
   `hl.dsp.cursor.move({x, y})` is the only way to move the pointer here, and a
   teleport produces enter and leave sequences that real motion does not — it made
   popouts look like they opened and closed on their own long after the behaviour
   had been fixed, and sent me chasing a bug the user could not reproduce. Useful
   for confirming that a hover path fires at all; worthless for judging whether
   hover *feels* right. `grim` captures and IPC queries also race the 180ms grace
   timer, so a sampled state reads as closed when it is merely closing.
53. **Several `qs -c stratum` instances at once make `qs ipc` and `qs kill` hang.**
   Test launches accumulated until IPC could not resolve a single target. Scripts
   that restart the shell must stop existing instances by PID first.
54. **`pkill -f <pattern>` matches the calling shell.** Hit a second time, having
   already documented it in §8: the pattern appears in the invoking command line,
   so the call kills its own session (exit 144). Enumerate with `ps`/`pgrep` and
   signal explicit PIDs.
55. **The installed `quickshell-git` was built against Qt 6.11.2 while the system has
   6.12.0.** It logs a crash warning on every start and affects Caelestia equally.
   Rebuild the package: `paru -S --rebuild quickshell-git`.
