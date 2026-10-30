#!/usr/bin/env bash
# Stratum installer.
#
# Installs everything the shell needs, links it into Quickshell, hooks its
# keybinds into Hyprland (after asking), and offers a few apps to go with it.
#
#   ./install.sh               interactive
#   ./install.sh --yes         install everything required without asking
#   ./install.sh --no-deps     only link the shell; install nothing
#   ./install.sh --apps vscode,spotify,vesktop
#                              also install these apps (see --list-apps)
#   ./install.sh --list-apps   show the apps on offer
#
# Re-running it is safe: anything already installed or set up is left alone.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
QS_DIR="$CONFIG_HOME/quickshell"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
HYPR_DIR="$CONFIG_HOME/hypr"

YES=0
DEPS=1
APPS=""
ASK_APPS=1

bold() { printf '\033[1m%s\033[0m\n' "$1"; }
say()  { printf '  %s\n' "$1"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$1" >&2; exit 1; }

ask() {
  # ask "question" default(y|n)
  local q=$1 def=${2:-y} reply
  if [ "$YES" = 1 ]; then [ "$def" = y ]; return; fi
  local hint="[Y/n]"; [ "$def" = n ] && hint="[y/N]"
  read -r -p "  $q $hint " reply || reply=""
  reply=${reply:-$def}
  [[ "$reply" =~ ^[Yy] ]]
}

# --- the apps on offer --------------------------------------------------------
# id | name | arch packages (aur ones too) | fedora packages | flatpak id
APP_LIST=(
  "vscode|Visual Studio Code|visual-studio-code-bin|code|com.visualstudio.code"
  "spotify|Spotify (with Spicetify)|spotify spicetify-cli||com.spotify.Client"
  "vesktop|Vesktop (Discord, with Vencord)|vesktop-bin||dev.vencord.Vesktop"
  "discord|Discord|discord||com.discordapp.Discord"
  "firefox|Firefox|firefox|firefox|org.mozilla.firefox"
  "steam|Steam|steam|steam|com.valvesoftware.Steam"
  "obs|OBS Studio|obs-studio|obs-studio|com.obsproject.Studio"
  "obsidian|Obsidian|obsidian||md.obsidian.Obsidian"
  "kitty|Kitty terminal|kitty|kitty|"
  "btop|btop (system monitor)|btop|btop|"
)

list_apps() {
  bold "Apps on offer"
  for a in "${APP_LIST[@]}"; do
    IFS='|' read -r id name _ _ _ <<<"$a"
    printf '  %-10s %s\n' "$id" "$name"
  done
}

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) YES=1 ;;
    --no-deps) DEPS=0 ;;
    --apps) APPS="${2:-}"; ASK_APPS=0; shift ;;
    --no-apps) ASK_APPS=0 ;;
    --list-apps) list_apps; exit 0 ;;
    -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done
[ "$YES" = 1 ] && [ -z "$APPS" ] && ASK_APPS=0

# --- which system -------------------------------------------------------------
DISTRO=other
if command -v pacman >/dev/null; then DISTRO=arch
elif command -v dnf >/dev/null; then DISTRO=fedora
elif command -v apt-get >/dev/null; then DISTRO=debian
fi

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

AUR=""
for h in paru yay; do command -v "$h" >/dev/null && { AUR=$h; break; }; done

has_nvidia() { command -v lspci >/dev/null && lspci | grep -qi 'vga.*nvidia\|3d.*nvidia'; }
has_battery() { ls /sys/class/power_supply/ 2>/dev/null | grep -q '^BAT'; }

# Arch: official repositories first, then the AUR for whatever is not there.
arch_install() {
  local want=() p
  for p in "$@"; do pacman -Qq "$p" >/dev/null 2>&1 || want+=("$p"); done
  [ ${#want[@]} -eq 0 ] && return 0
  local repo=() aur=()
  for p in "${want[@]}"; do
    if pacman -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
  done
  if [ ${#repo[@]} -gt 0 ]; then
    say "pacman: ${repo[*]}"
    $SUDO pacman -S --needed --noconfirm "${repo[@]}" || warn "pacman could not install some of: ${repo[*]}"
  fi
  if [ ${#aur[@]} -gt 0 ]; then
    if [ -z "$AUR" ]; then
      if ask "Some packages are in the AUR (${aur[*]}). Install the paru AUR helper to get them?" y; then
        $SUDO pacman -S --needed --noconfirm base-devel git
        local tmp; tmp=$(mktemp -d)
        git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
        (cd "$tmp/paru-bin" && makepkg -si --noconfirm)
        rm -rf "$tmp"
        AUR=paru
      else
        warn "skipped (AUR): ${aur[*]}"
        return 0
      fi
    fi
    say "$AUR: ${aur[*]}"
    $AUR -S --needed --noconfirm "${aur[@]}" || warn "$AUR could not install some of: ${aur[*]}"
  fi
}

fedora_install() {
  local want=() p
  for p in "$@"; do rpm -q "$p" >/dev/null 2>&1 || want+=("$p"); done
  [ ${#want[@]} -eq 0 ] && return 0
  say "dnf: ${want[*]}"
  $SUDO dnf install -y --skip-unavailable "${want[@]}" || warn "dnf could not install some of: ${want[*]}"
}

# --- 1. required tools --------------------------------------------------------
install_deps() {
  bold "1. Tools the shell uses"
  case "$DISTRO" in
    arch)
      local pkgs=(
        quickshell                       # the shell runtime
        qt6-svg qt6-imageformats qt6-shadertools qt6-5compat qt6-multimedia
        grim slurp satty wl-clipboard    # screenshots, region select, annotate, copy
        wireplumber pipewire-pulse       # volume (wpctl)
        brightnessctl ddcutil            # laptop backlight, external monitors
        power-profiles-daemon upower     # power profiles, battery
        hyprsunset                       # night light
        networkmanager bluez bluez-utils # Wi-Fi and Bluetooth
        gpu-screen-recorder              # screen recording
        matugen-bin                      # colours from the wallpaper
        plocate zenity libnotify pciutils curl git
      )
      has_nvidia && pkgs+=(nvidia-utils)
      # Already there under another package name (matugen from the repos rather
      # than matugen-bin, quickshell-git): left alone rather than fought over.
      local keep=() p
      for p in "${pkgs[@]}"; do
        case "$p" in
          quickshell) command -v qs >/dev/null && continue ;;
          matugen-bin) command -v matugen >/dev/null && continue ;;
          gpu-screen-recorder) command -v gpu-screen-recorder >/dev/null && continue ;;
        esac
        keep+=("$p")
      done
      arch_install "${keep[@]}"
      ;;
    fedora)
      if ! rpm -q quickshell >/dev/null 2>&1; then
        say "Quickshell comes from the errornous/quickshell COPR"
        $SUDO dnf copr enable -y errornous/quickshell || warn "could not enable the quickshell COPR"
      fi
      if ! command -v hyprsunset >/dev/null; then
        $SUDO dnf copr enable -y solopasha/hyprland || true
      fi
      fedora_install quickshell qt6-qtsvg qt6-qtimageformats qt6-qtshadertools qt6-qt5compat \
        grim slurp satty wl-clipboard wireplumber brightnessctl ddcutil power-profiles-daemon upower \
        hyprsunset NetworkManager bluez plocate zenity libnotify pciutils curl git
      if ! command -v matugen >/dev/null; then
        if command -v cargo >/dev/null; then
          cargo install matugen || warn "matugen could not be built"
        else
          warn "matugen: install Rust (dnf install cargo), then: cargo install matugen"
        fi
      fi
      command -v gpu-screen-recorder >/dev/null || warn "gpu-screen-recorder: install it from Flathub (com.dec05eba.gpu_screen_recorder) for screen recording"
      ;;
    *)
      warn "This installer knows Arch and Fedora. Install these yourself, then run it again with --no-deps:"
      say "quickshell grim slurp satty wl-clipboard wireplumber brightnessctl ddcutil power-profiles-daemon"
      say "upower hyprsunset networkmanager bluez gpu-screen-recorder matugen plocate zenity libnotify"
      return 0
      ;;
  esac
}

# --- 2. what the tools need set up --------------------------------------------
setup_system() {
  bold "2. Setting them up"

  # Power profiles and the file index run as services.
  if systemctl list-unit-files power-profiles-daemon.service >/dev/null 2>&1; then
    systemctl is-enabled --quiet power-profiles-daemon 2>/dev/null \
      || { $SUDO systemctl enable --now power-profiles-daemon && ok "power profiles enabled"; } \
      || warn "could not enable power-profiles-daemon"
  fi
  if systemctl list-unit-files plocate-updatedb.timer >/dev/null 2>&1; then
    systemctl is-enabled --quiet plocate-updatedb.timer 2>/dev/null \
      || { $SUDO systemctl enable --now plocate-updatedb.timer && ok "file index (launcher file search) enabled"; } \
      || true
  fi
  systemctl is-enabled --quiet bluetooth 2>/dev/null \
    || { systemctl list-unit-files bluetooth.service >/dev/null 2>&1 && $SUDO systemctl enable --now bluetooth && ok "bluetooth enabled"; } \
    || true

  # External monitor brightness goes over I2C, which needs a kernel module and
  # permission to use it.
  if command -v ddcutil >/dev/null; then
    if [ ! -f /etc/modules-load.d/i2c-dev.conf ]; then
      echo i2c-dev | $SUDO tee /etc/modules-load.d/i2c-dev.conf >/dev/null && $SUDO modprobe i2c-dev \
        && ok "i2c-dev loaded (external monitor brightness)"
    fi
    if getent group i2c >/dev/null && ! id -nG "$USER" | grep -qw i2c; then
      $SUDO usermod -aG i2c "$USER" && ok "added you to the i2c group (takes effect after logging out and in)"
    fi
  fi

  # rembg is heavy (a few hundred MB with its model), so it is offered, not assumed.
  if ! command -v rembg >/dev/null && ask "Install rembg for the wallpaper depth effect? (~400 MB, optional)" n; then
    case "$DISTRO" in
      arch) arch_install python-pipx ;;
      fedora) fedora_install pipx ;;
    esac
    pipx install 'rembg[cli,cpu]' && ok "rembg installed" || warn "rembg could not be installed"
  fi
}

# --- 3. the shell itself ------------------------------------------------------
link_shell() {
  bold "3. Linking Stratum"
  mkdir -p "$QS_DIR" "$BIN_DIR" "$CONFIG_HOME/stratum"
  ln -sfn "$ROOT" "$QS_DIR/stratum"
  ok "linked $QS_DIR/stratum → $ROOT"

  for tool in stratum stratumctl shellctl; do
    ln -sfn "$ROOT/cli/$tool" "$BIN_DIR/$tool"
  done
  ok "commands in $BIN_DIR: stratum, stratumctl, shellctl"

  mkdir -p "$ROOT/assets/fonts"
  fetch() {
    local name=$1 url=$2
    [ -s "$ROOT/assets/fonts/$name.ttf" ] && return
    if curl -fsSL --max-time 30 -o "$ROOT/assets/fonts/$name.ttf" "$url"; then
      ok "font $name"
    else
      warn "could not fetch the $name font — set font.$3 in theme.json to one you have"
    fi
  }
  fetch Doto   "https://github.com/google/fonts/raw/main/ofl/doto/Doto%5BROND,wght%5D.ttf" display
  fetch Geist  "https://github.com/google/fonts/raw/main/ofl/geist/Geist%5Bwght%5D.ttf" ui
  fetch Nunito "https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf" rounded

  case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "$BIN_DIR is not on your PATH — add it in your shell's config" ;;
  esac
}

# --- 4. Hyprland --------------------------------------------------------------
hook_hyprland() {
  bold "4. Hyprland"
  [ -d "$HYPR_DIR" ] || { warn "no $HYPR_DIR — is Hyprland set up?"; return; }

  local file line config
  if [ -f "$HYPR_DIR/hyprland.lua" ]; then
    file="$HYPR_DIR/stratum-binds.lua"; config="$HYPR_DIR/hyprland.lua"
    line='dofile(os.getenv("HOME") .. "/.config/hypr/stratum-binds.lua")'
    [ -f "$file" ] || cp "$ROOT/assets/hypr/stratum-binds.lua" "$file"
  else
    file="$HYPR_DIR/stratum-binds.conf"; config="$HYPR_DIR/hyprland.conf"
    line='source = ~/.config/hypr/stratum-binds.conf'
    [ -f "$file" ] || cp "$ROOT/assets/hypr/stratum-binds.conf" "$file"
  fi
  ok "binds file: $file (Stratum keeps it up to date from Settings → Keybinds)"

  # Once per session, not on every config reload.
  local autostart='exec-once = qs -c stratum'
  [ -f "$HYPR_DIR/hyprland.lua" ] && autostart='hl.on("hyprland.start", function() hl.exec_cmd("qs -c stratum") end)'

  if grep -qF "stratum-binds" "$config" 2>/dev/null; then
    ok "your config already loads it"
  elif ask "Add the line that loads it to the end of $(basename "$config")?" y; then
    local mark="--"; [ "${config##*.}" = conf ] && mark="#"
    printf '\n%s Stratum\n%s\n' "$mark" "$line" >>"$config"
    ok "added: $line"
  else
    say "add this yourself, at the end: $line"
  fi

  if grep -qE "qs -c stratum|quickshell.*stratum|stratum start" "$config" 2>/dev/null; then
    ok "Stratum already starts with Hyprland"
  elif ask "Start Stratum with Hyprland?" y; then
    printf '%s\n' "$autostart" >>"$config"
    ok "added: $autostart"
  fi
}

# --- 5. apps ------------------------------------------------------------------
install_app() {
  local id=$1 entry found=""
  for entry in "${APP_LIST[@]}"; do
    [ "${entry%%|*}" = "$id" ] && found=$entry
  done
  [ -n "$found" ] || { warn "no app called '$id' (see --list-apps)"; return; }
  IFS='|' read -r _ name archp fedp flat <<<"$found"
  say "→ $name"
  case "$DISTRO" in
    arch) [ -n "$archp" ] && arch_install $archp ;;
    fedora)
      if [ -n "$fedp" ]; then fedora_install $fedp
      elif [ -n "$flat" ] && command -v flatpak >/dev/null; then flatpak install -y flathub "$flat"
      else warn "$name: no Fedora package; install it from Flathub ($flat)"; fi ;;
    *) [ -n "$flat" ] && command -v flatpak >/dev/null && flatpak install -y flathub "$flat" ;;
  esac

  # Spicetify has to be allowed to change Spotify's files, then applied once.
  if [ "$id" = spotify ] && command -v spicetify >/dev/null; then
    for d in /opt/spotify /usr/share/spotify; do
      [ -d "$d" ] && $SUDO chmod a+wr "$d" && $SUDO chmod -R a+wr "$d/Apps" 2>/dev/null
    done
    spicetify backup apply >/dev/null 2>&1 && ok "Spicetify applied" \
      || warn "Spicetify: open Spotify once, close it, then run: spicetify backup apply"
  fi
}

pick_apps() {
  bold "5. Apps (optional)"
  list_apps
  local reply
  read -r -p "  Type the ones you want, separated by spaces (or 'all', or press Enter for none): " reply || reply=""
  [ "$reply" = all ] && reply=$(for a in "${APP_LIST[@]}"; do printf '%s ' "${a%%|*}"; done)
  APPS=${reply// /,}
}

# --- run ----------------------------------------------------------------------
echo
bold "Stratum installer  ·  $DISTRO"
echo

if [ "$DEPS" = 1 ]; then
  install_deps
  setup_system
fi
link_shell
hook_hyprland
[ "$ASK_APPS" = 1 ] && pick_apps
if [ -n "$APPS" ]; then
  [ "$ASK_APPS" = 0 ] && bold "5. Apps"
  IFS=',' read -ra chosen <<<"$APPS"
  for id in "${chosen[@]}"; do [ -n "$id" ] && install_app "$id"; done
fi

echo
bold "Checking"
"$ROOT/cli/stratum" doctor || true

echo
bold "Done"
say "Start it now with:   stratum start"
say "Update it later:     stratum update"
say "Something wrong?     stratum doctor, and docs/TROUBLESHOOTING.md"
