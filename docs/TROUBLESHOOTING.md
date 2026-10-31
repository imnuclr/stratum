# Troubleshooting

Start with:

```bash
stratum doctor
```

It checks every tool, whether Hyprland loads Stratum's keybinds, and whether you are
on the latest version, and says what to do about anything that is off. The shell's own
errors are in:

```bash
stratum log
```

If you're asking for help, include the output of both.

---

## Getting it running

### `stratum start` says it failed

Run it in the foreground to see why:

```bash
qs -c stratum
```

- **`module "qs.…" is not installed`** — a new folder was added in an update and the
  running Quickshell has not seen it. Stop it fully and start again:
  `stratum restart` (a hot reload is not enough).
- **`module "Quickshell…" is not installed`** — Quickshell is too old, or a Qt module is
  missing. On Arch: `paru -S quickshell qt6-svg qt6-imageformats qt6-shadertools qt6-5compat`.
- **Anything else** — open an issue with the full output.

### Text looks wrong or the numbers aren't dotted

The fonts didn't download. Run `./install.sh --no-deps` again with a working connection,
or check `assets/fonts/` has `Doto.ttf`, `Geist.ttf` and `Nunito.ttf`.

### Changes from an update don't show up

You're probably running the old copy. `stratum update` pulls and restarts. If you
updated with `git pull` yourself, also run `stratum restart`.

`stratum update` refuses to run when you've edited files in the folder: run
`git -C ~/stratum status` to see which, then `git stash` to set them aside.

---

### The lock screen crashed (red "lock screen crashed" screen)

Your session is still locked and safe. To get back in:

1. Press <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>F3</kbd> and log in on the text console.
2. Start the shell again on your desktop:
   ```bash
   hyprctl --instance 0 keyword misc:allow_session_lock_restore 1
   hyprctl --instance 0 dispatch exec "qs -c stratum"
   ```
   (Lua configs: `hyprctl --instance 0 dispatch '(function() hl.config({ misc = { allow_session_lock_restore = true } }) return hl.dsp.exec_cmd("qs -c stratum") end)()'`)
3. Press <kbd>Ctrl</kbd> <kbd>Alt</kbd> <kbd>F1</kbd> (or F2) to go back; the lock screen is
   there again and takes your password.

Stratum turns `allow_session_lock_restore` on itself while it runs, so usually step 2's
first line is already done. Then send the crash: `stratum log | tail -n 60`.

Test the lock screen without locking: `stratum ipc lock preview` (Escape closes it).

## Keys

### No Stratum keys work (Super + Space, screenshots, Super + L…)

Hyprland isn't loading Stratum's binds file. `stratum doctor` will say so. Add this
line **at the end** of your config:

- **Lua config** (`~/.config/hypr/hyprland.lua`):
  ```lua
  dofile(os.getenv("HOME") .. "/.config/hypr/stratum-binds.lua")
  ```
- **Classic config** (`~/.config/hypr/hyprland.conf`):
  ```conf
  source = ~/.config/hypr/stratum-binds.conf
  ```

Then `hyprctl reload`.

### One key does something else as well, or instead

Your own config binds the same keys. Stratum's file unbinds anything on its keys
before binding them, so make sure it's loaded **last** (at the very end of your config).
In **Settings → Keybinds**, keys used twice are outlined in red.

### Super + Space (the launcher) doesn't open

1. `stratum doctor` — is the launcher key bound?
2. Test the launcher without a key: `stratum ipc launcher toggle`.
   - It opens: the key is the problem. Bind it again in **Settings → Keybinds**
     (choose Space, then *launcher*), or **restore defaults** there.
   - It doesn't open: the shell has an error; check `stratum log`.

### Keybinds page shows "lua: …" or "a Lua function" instead of a description

Stratum reads your `.lua` files under `~/.config/hypr` to describe what each bind does.
If it can't follow one (it's built by a helper function, for instance), it shows that
bind's code. To give any bind your own words, add a comment on the same line:

```lua
hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus")) -- file manager
```

### No Print key for screenshots

Region: **Super + Shift + S**. Whole screen: **Super + Alt + P**. The control centre
also has a screenshot button, and the launcher finds "screenshot".

### An app key opens the app in a scratchpad / special workspace

That comes from your config, often a window rule or a `togglespecialworkspace` bind.
In **Settings → Keybinds**, pick the key, then **or open an app** and choose the app.
Stratum's version brings the app's window to the workspace you're on, from anywhere
(scratchpads included), or starts the app if it isn't running.

---

### Closing the lid does not lock

Stratum locks when the machine suspends, which is what closing a laptop's lid
normally does. If it does not:

1. Check the setting is on: **Settings → Power → Lock when it sleeps**.
2. Check closing the lid actually suspends:
   ```bash
   grep -i handlelidswitch /etc/systemd/logind.conf /etc/systemd/logind.conf.d/*.conf 2>/dev/null
   ```
   `HandleLidSwitch=ignore` means something else (often Hyprland) is handling it.
   With Hyprland handling it, lock from your config instead:
   ```lua
   hl.bindl("", "switch:on:Lid Switch", hl.dsp.global("stratum:lock"))
   ```
   (classic config: `bindl = , switch:on:Lid Switch, global, stratum:lock`)
3. Test the path without the lid: `systemctl suspend`. If that locks, the lid is
   the part that is not suspending.

## Looks

### "Colours from wallpaper" says matugen isn't installed, but it is

Ask the running shell what it knows:

```bash
stratum ipc palette status
```

It prints the matugen it found (if any), how the search went, the wallpaper it would
read, and any error. Then:

- **`matugen: (none)`** and **`search: found nothing`** — the shell can't see it. Find
  where it is with `command -v matugen` in your terminal, and tell the shell:
  ```bash
  stratum ipc config set theme.matugen '"/usr/bin/matugen"'
  ```
  (use the path you got). `stratum ipc palette find` searches again.
- **`matugen: /…/matugen`** but colours don't change — check **mode** isn't `off`
  (Settings → Appearance → Colours from wallpaper → accent or full), then
  `stratum ipc palette run` and look at **error**.
- **`error: matugen: …`** — matugen ran and complained. Try the same thing yourself:
  ```bash
  matugen image ~/path/to/wallpaper.jpg --json hex --dry-run
  ```
  If that asks you to pick a colour, add `--source-color-index 0` (Stratum does).
- **`image: (no wallpaper)`** — Stratum isn't drawing a wallpaper on your first screen;
  set one in Settings → Wallpaper.

### The dotted wallpaper is black

The dots are drawn by a small GPU program, and some drivers refuse it. Stratum now
falls back to the plain picture when that happens, so a black desktop means an older
version: run `stratum update`, then `stratum restart`.

If it is still black after updating, find out what the driver said:

```bash
stratum ipc config set debug.trace true
stratum restart
stratum log 200 | grep -i wallpaper
```

Send that line. To use the plain picture in the meantime, either pick **original**
in Settings → Wallpaper, or:

```bash
stratum ipc config set wallpaper.shader false
```

### The wallpaper depth effect does nothing

- It needs **rembg** (`pipx install 'rembg[cli,cpu]'`) and the drift set to **depth**
  in **Settings → Wallpaper**.
- The first cutout downloads a model (~170 MB), so give it a minute; the wallpaper
  page shows progress as *cutout · …*.
- It's skipped for the **dots** look.

### The clock is still 24-hour

**Settings → Appearance → 24-hour time**. Desktop clock widgets have their own setting
(hold the widget → options → hours); **auto** follows the switch.

---

### The accent doesn't reach my terminal, Spotify or Discord

Switch each on in **Settings → Appearance → Apps**. Then:

- **kitty / ghostty** change at once. **foot / alacritty** from the next window.
- **Spotify** needs Spicetify installed and applied once (`spicetify backup apply`);
  switching it on selects the Stratum theme and restarts Spotify.
- **Vesktop / Discord (Vencord)**: open Vencord settings → Themes and tick
  **Stratum** once. It follows the shell's colours live after that.
- **GTK apps** pick it up when they next open.

## Hardware

### External monitor brightness doesn't change

It goes over DDC/CI, which needs:

```bash
sudo modprobe i2c-dev
echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf
sudo usermod -aG i2c $USER     # then log out and in
ddcutil detect                 # should list your monitor
```

Some monitors have DDC/CI switched off in their own on-screen menu; turn it on there.

### Laptop brightness doesn't change

`brightnessctl` needs to be installed and you need to be in the `video` group on some
systems: `sudo usermod -aG video $USER`.

### Power profiles are missing

```bash
sudo systemctl enable --now power-profiles-daemon
```

TLP and power-profiles-daemon conflict; use one.

### Night light is greyed out

Install `hyprsunset` (Arch: `pacman -S hyprsunset`).

### Screen recording does nothing

Install `gpu-screen-recorder`. On NVIDIA, the proprietary driver is required.

### Wi-Fi or Bluetooth lists are empty

Stratum talks to **NetworkManager** and **BlueZ**:

```bash
sudo systemctl enable --now NetworkManager bluetooth
```

(iwd on its own, or systemd-networkd, aren't supported for the Wi-Fi list.)

### The launcher doesn't find files

It uses `plocate`'s index, which updates daily:

```bash
sudo systemctl enable --now plocate-updatedb.timer
sudo updatedb    # index now
```

Without plocate it falls back to a slower search of your home folder.

---

## Apps

### Spicetify: "cannot find Spotify" or changes don't apply

Open Spotify once and close it (it has to create its config), then:

```bash
sudo chmod a+wr /opt/spotify && sudo chmod -R a+wr /opt/spotify/Apps
spicetify backup apply
```

After a Spotify update: `spicetify restore backup apply`.

---

## Still stuck

Open an issue at <https://github.com/imnuclr/stratum/issues> with the output of
`stratum doctor` and the last lines of `stratum log`.
