#!/usr/bin/env bash
# Link Stratum into Quickshell, fetch vendored fonts, expose the CLI tools.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

say() { printf '  %s\n' "$1"; }

command -v qs >/dev/null || { say "quickshell is not installed"; exit 1; }

mkdir -p "$QS_DIR" "$BIN_DIR" "${XDG_CONFIG_HOME:-$HOME/.config}/stratum"
ln -sfn "$ROOT" "$QS_DIR/stratum"
say "linked $QS_DIR/stratum"

for tool in stratum stratumctl shellctl; do
  ln -sfn "$ROOT/cli/$tool" "$BIN_DIR/$tool"
  say "linked $BIN_DIR/$tool"
done

mkdir -p "$ROOT/assets/fonts"
fetch() {
  local name=$1 url=$2
  [ -s "$ROOT/assets/fonts/$name.ttf" ] && { say "$name already present"; return; }
  if curl -fsSL --max-time 30 -o "$ROOT/assets/fonts/$name.ttf" "$url"; then
    say "fetched $name"
  else
    say "could not fetch $name — set font.$3 in theme.json to a face you have"
  fi
}
fetch Doto  "https://github.com/google/fonts/raw/main/ofl/doto/Doto%5BROND,wght%5D.ttf" display
fetch Geist "https://github.com/google/fonts/raw/main/ofl/geist/Geist%5Bwght%5D.ttf"    ui
fetch Nunito "https://github.com/google/fonts/raw/main/ofl/nunito/Nunito%5Bwght%5D.ttf" rounded

# Hyprland binds. Written next to the user's config but never into it: the
# config may be Lua-generated, and a shell that rewrites the compositor's config
# is a shell that loses someone's keybinds. The line to add is printed instead.
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
if [ -d "$HYPR_DIR" ]; then
  if [ -f "$HYPR_DIR/hyprland.lua" ]; then
    cp "$ROOT/assets/hypr/stratum-binds.lua" "$HYPR_DIR/stratum-binds.lua"
    say "wrote $HYPR_DIR/stratum-binds.lua"
    say "  add to the end of your user config:"
    say "    dofile(os.getenv(\"HOME\") .. \"/.config/hypr/stratum-binds.lua\")"
  else
    cp "$ROOT/assets/hypr/stratum-binds.conf" "$HYPR_DIR/stratum-binds.conf"
    say "wrote $HYPR_DIR/stratum-binds.conf"
    say "  add to hyprland.conf:"
    say "    source = ~/.config/hypr/stratum-binds.conf"
  fi
fi

# Everything optional, and named with what it is for, because a laptop install
# will be missing a different set to a desktop one.
echo
say "optional tools:"
check() {
  if command -v "$1" >/dev/null; then
    say "  present  $1 — $2"
  else
    say "  missing  $1 — $2"
  fi
}
check grim            "screenshots"
check slurp           "region select"
check satty           "screenshot annotation"
check wpctl           "volume (pipewire)"
check ddcutil         "external monitor brightness"
check brightnessctl   "laptop backlight"
check powerprofilesctl "power profiles"
check nvidia-smi      "gpu metrics"
check gpu-screen-recorder "screen recording"
check hyprsunset      "night light"
check matugen         "colour theming from wallpaper"
check rembg           "wallpaper cutouts for depth (pipx install 'rembg[cli,cpu]')"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say "add $BIN_DIR to your PATH" ;;
esac

echo
say "done — start with: stratum start"
