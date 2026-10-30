pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * A file or folder chooser, borrowed from whichever of zenity, kdialog or yad
 * is installed. The shell has no dialogs of its own, and a native chooser is
 * what people expect when asked for a file.
 *
 *     Picker.file("Profile picture", true, path => ...)
 *     Picker.folder("Wallpaper folder", path => ...)
 */
Singleton {
    id: root

    property var done: null
    readonly property bool busy: chooser.running

    function file(title, images, then) {
        root.ask(title, false, images, then);
    }

    function folder(title, then) {
        root.ask(title, true, false, then);
    }

    function ask(title, dir, images, then) {
        if (chooser.running)
            return;
        root.done = then;
        chooser.command = ["sh", "-c", `
            t="$1"; d="$2"; i="$3"
            if command -v zenity >/dev/null 2>&1; then
                if [ "$d" = 1 ]; then zenity --file-selection --directory --title="$t"
                elif [ "$i" = 1 ]; then zenity --file-selection --title="$t" --file-filter="Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg"
                else zenity --file-selection --title="$t"; fi
            elif command -v kdialog >/dev/null 2>&1; then
                if [ "$d" = 1 ]; then kdialog --title "$t" --getexistingdirectory "$HOME"
                elif [ "$i" = 1 ]; then kdialog --title "$t" --getopenfilename "$HOME" "image/png image/jpeg image/webp image/gif"
                else kdialog --title "$t" --getopenfilename "$HOME"; fi
            elif command -v yad >/dev/null 2>&1; then
                if [ "$d" = 1 ]; then yad --file --directory --title="$t"; else yad --file --title="$t"; fi
            else
                echo "!none"
            fi`, "sh", title, dir ? "1" : "0", images ? "1" : "0"];
        chooser.running = true;
    }

    // Set when no chooser could be found, for the page to explain.
    property bool missing: false

    Process {
        id: chooser

        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                root.missing = path === "!none";
                if (path.length > 0 && !root.missing && root.done)
                    root.done(path);
                root.done = null;
            }
        }
    }
}
