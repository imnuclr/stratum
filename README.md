<h1>Stratum</h1>

A Wayland desktop shell for Hyprland, built on [Quickshell](https://quickshell.org).

> **str. 1** wallpaper + depth &middot; **str. 2** widget canvas &middot; **str. 3** bar + panels &middot; **str. 4** overlays + lock

The name is the architecture: Stratum renders the desktop as discrete layers, and the
wallpaper's subject sits *in front of* your widgets rather than behind them.

Visually it follows Nothing OS. Dots are the rendering primitive, not just a typeface —
every gauge is a dotted ring, every progress bar a row of dots, every sparkline a dot
field, and album art is dithered into dots. Five greys and one red.

## Status

Phase 1 of 8. The bar is daily-drivable on both monitors: live clock, workspaces,
focused window, system tray, and a status cluster wired to real services.
See [`DESIGN.md`](DESIGN.md) for the full plan.

- [x] **0** &mdash; skeleton, config + theme singletons, dot primitives
- [x] **1** &mdash; bar: tray, status cluster, active window
- [ ] **2** &mdash; remaining services (media, notifications, GPU, weather, sysstats)
- [ ] **3** &mdash; dashboard strip + control centre
- [ ] **4** &mdash; wallpaper layer + depth parallax
- [ ] **5** &mdash; widget canvas + edit mode
- [ ] **6** &mdash; lock screen
- [ ] **7** &mdash; settings app
- [ ] **8** &mdash; launcher, OSD, polish

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
