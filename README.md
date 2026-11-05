<p align="center">
  <img src="docs/images/banner.png" alt="Stratum" width="100%">
</p>

<p align="center">
  <b>A desktop shell for Hyprland, in dots.</b><br>
  Built on <a href="https://quickshell.org">Quickshell</a> · inspired by Nothing OS · your colours, or your wallpaper's
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#what-you-get">What you get</a> ·
  <a href="#keys">Keys</a> ·
  <a href="#control-it-from-anywhere">stratumctl</a> ·
  <a href="docs/TROUBLESHOOTING.md">Troubleshooting</a>
</p>

---

Stratum draws the whole desktop as layers — wallpaper, widgets, bar and panels,
overlays, lock screen — and draws all of it in dots. Every gauge is a dotted ring,
every progress bar a row of dots, the clock a dot matrix, album art dithered into
dots. It takes its colours from you: one accent you pick, or a full matched palette
from your wallpaper, carried into your terminal, Spotify, Discord and GTK apps.

## What you get

<table>
<tr>
<td width="50%" valign="top">

**Bar** — a column down either side or a strip along the top, per monitor.
Workspaces, clock, tray (with its menus right in a popout), and hover popouts for
Wi-Fi, Bluetooth, sound and battery.

**Sidebar** — reached by running the pointer into the right edge of the screen.
Notifications at the top, then Wi-Fi, Bluetooth, focus, brightness and volume
(scroll them), toggles you arrange yourself, including **game mode** and VPN
(WARP, Tailscale, Mullvad, NetworkManager), now playing; the clock, settings and
power on the floor of it.

**Launcher** — <kbd>Super</kbd> + <kbd>Space</kbd>. Apps ranked by how often you
open them, files, open windows, single settings, actions and sums, with a preview
beside the list. Type <code>&gt;</code> to search one kind.

**Dashboard** — time, weather, processor/memory/GPU rings, per-core load, top
processes by CPU, memory or GPU, network, media.

</td>
<td width="50%" valign="top">

**Desktop widgets** — fourteen of them on a snapping grid, per monitor: clock,
greeting, weather, calendar, now playing, lyrics, gauges, photo. They step aside
for windows, and pick light or dark ink from the wallpaper behind them.

**Lyrics** — the words of whatever is playing, swept **word by word** rather than
a line at a time. On the desktop as a widget, or over the whole screen with
<kbd>Super</kbd> + <kbd>Y</kbd>. See [Lyrics](#lyrics).

**Lock screen** — a real session lock with a composed entrance, your photo, and a
password row of dots.

**Settings** — a proper window with search that forgives typos and knows other
words for things. Displays you can drag to arrange, sound, network, Bluetooth,
power profiles with energy savers, motion, weather with a map, keybinds drawn as a
keyboard, updates.

**Colours everywhere** — accent or wallpaper (matugen) colours applied to the
shell, window borders, terminal, Spotify (Spicetify), Vesktop and GTK.

</td>
</tr>
</table>


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

### Updating

```bash
stratum update
```

### Something wrong?

Run `stratum doctor` first — it names what is missing and how to fix it. Then see
**[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**, which covers each problem
people have hit, and `stratum log` for the shell's own errors.

## Keys

| Keys | Does |
|---|---|
| <kbd>Super</kbd> <kbd>Space</kbd> | launcher |
| <kbd>Super</kbd> <kbd>Shift</kbd> <kbd>S</kbd> · <kbd>Print</kbd> | screenshot a region |
| <kbd>Super</kbd> <kbd>Alt</kbd> <kbd>P</kbd> | screenshot the screen |
| <kbd>Ctrl</kbd> <kbd>Print</kbd> | screenshot and annotate |
| <kbd>Alt</kbd> <kbd>Print</kbd> | record a region (again to stop) |
| <kbd>Super</kbd> <kbd>Shift</kbd> <kbd>W</kbd> | arrange desktop widgets |
| <kbd>Super</kbd> <kbd>Y</kbd> | lyrics, full screen |
| <kbd>Super</kbd> <kbd>L</kbd> | lock |

Change any of them, or bind a key to an app, in **Settings → Keybinds**. An app key
brings that app's window to the workspace you're on, or starts it.

## Control it from anywhere

`stratumctl` talks to the running shell, for scripts and your own binds:

```bash
stratumctl launcher firefox     # open the launcher, already searching
stratumctl game on              # game mode
stratumctl settings weather     # settings, on a page
stratumctl wallpaper random
stratumctl lyrics status        # which source answered, and how exact
stratumctl screenshot screen
stratumctl profile eco
stratumctl check && stratumctl updates
```

`stratumctl` alone lists everything. `stratum start | stop | restart | log | doctor |
update` looks after the shell itself.

## Lyrics

The words of whatever is playing, timed to it — and timed to the **word**, not
just the line, so the sweep tells you where in a line you are rather than only
which line it is.

Two places to see them: a **lyrics widget** on the desktop (right-click the
wallpaper to arrange, then pick it), a window onto the song that follows along —
how many lines it shows is one of its options, and that sets the type size
rather than the card's, so asking for more makes the words smaller; and a **full-screen view** on <kbd>Super</kbd> + <kbd>Y</kbd>, which shows
the whole song, follows along, and lets you click a line to seek to it.

Word timings come from [Spicy Lyrics](https://spicylyrics.org), which is the one
public source that has them. Their API wants a free key:

1. Go to [developers.spicylyrics.org](https://developers.spicylyrics.org) and
   sign in.
2. Create an application. You are shown a **secret key** (`sl_sk_…`) once — copy
   it then.
3. Paste it into **Settings → Lyrics**, or run
   `stratumctl lyrics key sl_sk_…`.

It is stored in `~/.config/stratum/spicylyrics.key`, on its own and not in
`shell.json` — that is the file people paste into issues and push to dotfile
repos, and a secret does not belong in it.

Without a key the shell falls back to [LRCLIB](https://lrclib.net), which needs
no account but only knows where each *line* starts.

Lines that overlap — a duet, a backing vocal, one singer coming in over the end
of the other's line — all light at once rather than one of them being skipped.

**Not every track has word timings, key or no key.** Spicy Lyrics answers with
the best sync it holds, and for many tracks that is Apple Music's or Spotify's,
which time the line and not the words in it. When that happens the line lights
whole rather than being swept — a sweep is a claim about where in the line the
voice is, and guessing at it reads as the lyrics being out of time rather than
as an estimate. The label above the words says which you are looking at: **word
by word**, or **timed by line**.

If the sweep runs ahead of or behind the voice, nudge it in **Settings → Lyrics →
Offset**. Position comes over a bus and is always a little behind what has
actually been played. `stratumctl lyrics status` says which source answered and
whether the timing is exact.

## Wallpapers

Eight come with it, made for Stratum (copied to `~/Pictures/Wallpapers` by the
installer). Any picture works — drawn as it is, or as dots.

<p align="center">
  <img src="docs/images/wallpapers.jpg" alt="The wallpapers that come with Stratum" width="85%">
</p>

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

## Switching shells

Stratum installs alongside any other Quickshell config rather than replacing it.
`shellctl` owns which one holds the session:

```sh
shellctl              # interactive picker (uses fzf when present)
shellctl list         # what's installed, and what's running
shellctl use stratum
shellctl use caelestia # also: cykler, cykler-caelestia
shellctl restart
```

The choice persists to `~/.config/stratum/active-shell`, so your Hyprland autostart can
read it instead of hardcoding one shell:

```conf
exec-once = shellctl use "$(cat ~/.config/stratum/active-shell 2>/dev/null || echo stratum)"
```

### Keybinds per shell

Two shells means two sets of binds, and loading both at once is what breaks the Super
key: an overlay unbinds a key before claiming it, so whichever file Hyprland read last
wins the key and aims it at a global — `stratum:launcher` — that the *running* shell
never answers. Hyprland therefore loads exactly one overlay, the active shell's:

```sh
shellctl binds setup   # once: adds the loader to ~/.config/hypr/hyprland.lua
shellctl binds doctor  # check the wiring
```

That writes `~/.config/hypr/shellctl-binds.lua`, which reads `active-shell` and pulls in
only that shell's overlay, then starts that shell:

| shell | overlay | written by |
| --- | --- | --- |
| `stratum` | `~/.config/hypr/stratum-binds.lua` | Settings → Keybinds |
| `caelestia` | `~/.config/hypr/caelestia-binds.lua` | by hand; caelestia's own binds already come from its dots |

On top of that, `shellctl` keeps a profile per shell, so the config each one owns travels
with it. `shellctl use` saves the outgoing shell's files and restores the incoming one's
before reloading Hyprland:

```sh
shellctl binds show          # what's tracked, saved and live for each shell
shellctl binds save          # snapshot the active shell's files
shellctl binds load stratum  # put a shell's saved set back
shellctl binds diff          # what's changed since the last save
shellctl binds track PATH    # carry another file between shells
```

Tracked by default — edit the list in `~/.config/shellctl/tracked`:

```
.config/hypr/stratum-binds.lua
.config/hypr/caelestia-binds.lua
.config/caelestia/hypr-vars.lua
.config/caelestia/hypr-user.lua
```

Restoring is additive: a file the profile doesn't hold is left alone rather than deleted,
so a half-filled profile never costs you a config file.


## Status

Daily-drivable on two monitors. The roadmap, and the lessons learned along the way,
are in [`DESIGN.md`](DESIGN.md).

- [x] **0** — skeleton, config and theme, dot primitives
- [x] **1** — bar: workspaces, tray, status, popouts
- [x] **2** — services: system stats, media, network, weather, notifications, GPU
- [x] **3** — dashboard and control centre
- [x] **4** — wallpaper: per monitor, crossfaded, dots, cutout depth
- [x] **5** — desktop widgets and edit mode
- [x] **6** — lock screen
- [x] **7** — settings window
- [x] **8** — polish: toasts, OSD, launcher, `stratumctl`, installer, updates, screenshots

## Requirements

Hyprland 0.50 or newer (Lua or classic config), Quickshell 0.3+, Qt 6.8+.
Everything else is installed by `install.sh`.

## Credits

Map outlines from [Natural Earth](https://www.naturalearthdata.com/) (public domain);
place names from [OpenStreetMap](https://www.openstreetmap.org/copyright); weather
from [Open-Meteo](https://open-meteo.com/). Discord theme built on
[Midnight](https://github.com/refact0r/midnight-discord). Fonts: Doto, Geist, Nunito
(SIL OFL).

## Licence

GPL-3.0
