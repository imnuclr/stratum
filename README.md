<h1>Stratum</h1>

A Wayland desktop shell for Hyprland, built on [Quickshell](https://quickshell.org).

> **str. 1** wallpaper + depth &middot; **str. 2** widget canvas &middot; **str. 3** bar + panels &middot; **str. 4** overlays + lock

The name is the architecture: Stratum renders the desktop as discrete layers, and the
wallpaper's subject sits *in front of* your widgets rather than behind them.

Visually it follows Nothing OS. Dots are the rendering primitive, not just a typeface —
every gauge is a dotted ring, every progress bar a row of dots, every sparkline a dot
field, and album art is dithered into dots. Five greys and one red.

## Status

Daily-drivable on both monitors. Phases follow the roadmap in
[`DESIGN.md`](DESIGN.md) §10, which also records the lessons learned along the way.

- [x] **0** &mdash; skeleton, config + theme singletons, dot primitives
- [x] **1** &mdash; bar: per-display workspaces, tray, status cluster, active window, popouts
- [x] **2** &mdash; services: SysStats, Media, Netstat, Weather, Notifications. *Gpu remains.*
- [x] **3** &mdash; dashboard + control centre. Wi-Fi and Bluetooth lists open above the
      panel, brightness is per monitor. *In-place tile expansion remains.*
- [ ] **4** &mdash; wallpaper + depth. **Wallpaper layer done**: drawn by the shell per
      monitor, crossfaded, per-monitor choice. *Cutout parallax, depth shader and
      shader-based transitions remain* (qt6-shadertools is installed).
- [ ] **5** &mdash; widget canvas + edit mode
- [x] **6** &mdash; lock screen: real session lock, dithered avatar, time-of-day
      greeting, smooth password box. Locks from SUPER + L, the session menu or
      `loginctl lock-session`; `qs -c stratum ipc call lock preview` shows it without
      locking. Password unlock confirmed on real hardware. *Fingerprint and a
      wallpaper backdrop remain.*
- [ ] **7** &mdash; settings. **Started**: a centred panel from the control centre's
      gear with wallpaper, appearance, notifications and advanced pages, and a safe
      config/theme writer behind it. Clicks on its controls are untested (needs a
      synthetic pointer). Open on a page with `qs -c stratum ipc call panel settings <page>`.
      *Still to come: bar, monitors and keybind pages; the schema-driven version.*
- [ ] **8** &mdash; polish. **Toasts done** (focused monitor only, hover holds, urgent
      ones stay, do-not-disturb). *OSD, launcher, remaining widgets, `stratumctl`,
      install script and screenshots remain.*

### Not in the roadmap

Work that doesn't belong to a phase above:

- **Colour theming from the wallpaper** (matugen is installed), keeping the single red
  accent as an option. The accent picker already exists in Settings.
- **Motion pass**: one soft curve for large surfaces, shorter exits, measured in time.

### Known loose ends

- `Tray.qml` uses a conditional `duration` on a Behavior, the pattern that silently
  failed elsewhere (DESIGN.md, lesson 45). Unchecked.
- `debug.trace` is on by default; decide whether it should be off.
- Battery and power profiles were written on a desktop and have not been seen on a laptop yet.
- Clicking is untested in automated checks: it needs `ydotoold`, which has not been
  started.

## Install

```sh
git clone https://github.com/imnuclr/stratum ~/Documents/Github/stratum
cd ~/Documents/Github/stratum && ./install.sh
```

`install.sh` links the shell into `~/.config/quickshell/stratum`, fetches the vendored
fonts, and puts `stratumctl` and `shellctl` on your `PATH`. Then:

```sh
qs -c stratum
```

## Switching shells

Stratum installs alongside any other Quickshell config rather than replacing it.
`shellctl` owns which one holds the session:

```sh
shellctl              # interactive picker (uses fzf when present)
shellctl list         # what's installed, and what's running
shellctl use stratum
shellctl use caelestia
shellctl restart
```

The choice persists to `~/.config/stratum/active-shell`, so your Hyprland autostart can
read it instead of hardcoding one shell:

```conf
exec-once = shellctl use "$(cat ~/.config/stratum/active-shell 2>/dev/null || echo stratum)"
```

## Configuration

Everything lives in `~/.config/stratum/`. Edits apply to the running shell; only code
changes need a reload.

| File | Purpose |
|---|---|
| `shell.json` | behaviour: bar layout, modules, keybinds, per-monitor overrides |
| `theme.json` | tokens: colour, radius, spacing, fonts, motion |
| `widgets.json` | widget canvas instances (written by edit mode) |
| `user/` | drop-in QML that shadows any built-in file |

Per-monitor overrides are first-class:

```jsonc
{
  "bar": { "layout": "thirds" },
  "monitors": {
    "HDMI-A-1": { "bar": { "layout": "edges", "height": 32 } }
  }
}
```

`layout: "thirds"` anchors the three bar islands at 25 / 50 / 75% rather than
left/centre/right &mdash; on an ultrawide, edge anchoring leaves 1,700px between the clock
and the status cluster.

Drop a file in `~/.config/stratum/user/` to replace any built-in without forking:

```
~/.config/stratum/user/components/Tile.qml          replaces the built-in Tile
~/.config/stratum/user/modules/widgets/MyThing.qml  a new widget, no fork needed
```

## Requirements

Hyprland, Quickshell 0.3+, Qt 6.8+. `matugen` for wallpaper-derived palettes and
`qt6-shadertools` for the depth shader are optional until phases 4 and 5.

## Licence

GPL-3.0
