pragma Singleton

import QtQuick
import Quickshell

/*
 * Finding a program that may not be on the shell's own path.
 *
 * The shell is often started from somewhere that lacks the directories a user's
 * tools live in — cargo's and pipx's bin directories, a Nix profile, anything a
 * login shell adds in its own config — so `command -v` in the shell's environment
 * says "not installed" for things that plainly are. This looks in the usual places
 * and then asks the user's own login shell, and prints the full path or nothing.
 * Run it as: sh -c <Bin.finder> sh <name>
 */
Singleton {
    readonly property string finder: `
        n="$1"
        for d in "$HOME/.cargo/bin" "$HOME/.local/bin" /usr/local/bin /usr/bin /bin "$HOME/go/bin" \
                 "$HOME/.nix-profile/bin" /run/current-system/sw/bin /home/linuxbrew/.linuxbrew/bin "$HOME/.local/share/pipx/venvs/$n/bin"; do
            [ -x "$d/$n" ] && { echo "$d/$n"; exit 0; }
        done
        p=$(command -v "$n" 2>/dev/null)
        [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; exit 0; }
        for s in "$SHELL" fish zsh bash; do
            p=$("$s" -lc "command -v $n" 2>/dev/null | tail -n1)
            [ -n "$p" ] && [ -x "$p" ] && { echo "$p"; exit 0; }
        done
        exit 1
    `
}
