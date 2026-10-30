<h1>Stratum</h1>

A Wayland desktop shell for Hyprland, built on [Quickshell](https://quickshell.org).

> **str. 1** wallpaper + depth &middot; **str. 2** widget canvas &middot; **str. 3** bar + panels &middot; **str. 4** overlays + lock

The name is the architecture: Stratum renders the desktop as discrete layers, and the
wallpaper's subject sits *in front of* your widgets rather than behind them.

Visually it follows Nothing OS. Dots are the rendering primitive, not just a typeface —
every gauge is a dotted ring, every progress bar a row of dots, every sparkline a dot
field, and album art is dithered into dots. Five greys and one red.

## Install

Stratum runs on **Hyprland** (0.50 or newer; Lua and classic `.conf` configs both work)
through **Quickshell**. The installer sets up everything else.

### 1. Get it

```bash
git clone https://github.com/imnuclr/stratum.git ~/stratum
cd ~/stratum
```

Keep the folder: Quickshell runs Stratum straight from it, so updating is a `git pull`.

### 2. Run the installer

```bash
./install.sh
```

It walks through five steps, asking before anything that changes your system:

1. **Tools** — installs everything the shell uses, automatically:

   | Tool | For |
   |---|---|
   | quickshell | the shell runtime |
   | grim, slurp, satty, wl-clipboard | screenshots, region select, annotation, copying |
   | wireplumber (`wpctl`) | volume |
   | brightnessctl, ddcutil | laptop and external-monitor brightness |
   | power-profiles-daemon, upower | power profiles, battery |
   | hyprsunset | night light |
   | networkmanager, bluez | Wi-Fi, Bluetooth |
   | gpu-screen-recorder | screen recording |
   | matugen | colours from the wallpaper |
   | plocate, zenity, libnotify | launcher file search, file chooser, notifications |
   | nvidia-utils | GPU readings — only on machines with an NVIDIA card |

   On **Arch** it uses pacman, and an AUR helper (paru or yay; it offers to install paru
   if you have neither) for quickshell, matugen and gpu-screen-recorder. On **Fedora**
   it uses dnf and the `errornous/quickshell` COPR. On anything else it prints the list
   to install yourself — then run `./install.sh --no-deps`.

2. **Setup** — turns on the power-profiles, Bluetooth and file-index services, and sets
   up I2C so external monitors' brightness can be changed (you are added to the `i2c`
   group; log out and back in once for that). Offers **rembg** (optional, ~400 MB) for
   the wallpaper depth effect.
3. **Linking** — links the folder into `~/.config/quickshell/stratum`, puts the
   `stratum`, `stratumctl` and `shellctl` commands in `~/.local/bin`, and fetches the
   fonts.
4. **Hyprland** — writes `~/.config/hypr/stratum-binds.lua` (or `.conf`) and, if you
   say yes, adds the one line that loads it to the end of your config, plus a line
   that starts Stratum with Hyprland. Nothing else in your config is touched.
5. **Apps (optional)** — pick any of: VS Code, Spotify (with Spicetify set up),
   Vesktop, Discord, Firefox, Steam, OBS, Obsidian, Kitty, btop.

Non-interactive: `./install.sh --yes`. Apps without asking:
`./install.sh --apps vscode,spotify,vesktop` (`--list-apps` shows them all).

### 3. Start it

```bash
stratum start
```

Or log out and back in if you let the installer add it to Hyprland. Then check
everything is in order:

```bash
stratum doctor
```

### Keys to know

| Keys | Does |
|---|---|
| Super + Space | launcher: apps, files, settings, sums |
| Super + Shift + S, or Print | screenshot a region |
| Super + Alt + P | screenshot the screen |
| Super + Shift + W | arrange desktop widgets |
| Super + L | lock |

All of them, and binding apps to keys, are in **Settings → Keybinds**.

### Updating

```bash
stratum update
```

### Something wrong?

Run `stratum doctor` first — it names what is missing and how to fix it. Then see
**[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**, which covers each problem
people have hit, and `stratum log` for the shell's own errors.

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
- [x] **5** &mdash; widget canvas + edit mode: thirteen widgets on a snapping grid, per
      monitor; hold a widget, right-click the desktop or Super + Shift + W to arrange,
      with a gallery to add from and per-widget options. They pause and fade behind
      windows. *Widgets do not yet avoid overlapping each other.*
- [x] **6** &mdash; lock screen: real session lock, dithered avatar, time-of-day
      greeting, smooth password box. Locks from SUPER + L, the session menu or
      `loginctl lock-session`; `qs -c stratum ipc call lock preview` shows it without
      locking. Password unlock confirmed on real hardware. *Fingerprint and a
      wallpaper backdrop remain.*
- [ ] **7** &mdash; settings, as a real window (Super + Q closes it, Super + drag moves
      it) with wallpaper, appearance, bar, monitors, widgets, keybinds, notifications
      and advanced pages. Keybinds is a keyboard: every key outlined by what is bound to
      it, conflicts in red, and the shell's own binds edited in place and written to
      the stratum-binds file. Open on a page with
      `qs -c stratum ipc call panel settings <page>`. *Still to come: the schema-driven
      version.*
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
- Battery and power profiles: detection fixed after a first run on a laptop; the bar battery and profile control are still to be confirmed by eye.
- Clicking is untested in automated checks: it needs `ydotoold`, which has not been
  started.

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

Hyprland 0.50+, Quickshell 0.3+, Qt 6.8+. Everything else is installed by
`install.sh` — see [Install](#install).

## Licence

GPL-3.0
