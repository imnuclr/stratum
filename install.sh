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

for tool in stratumctl shellctl; do
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

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) say "add $BIN_DIR to your PATH" ;;
esac

echo
say "done — start with: qs -c stratum"
