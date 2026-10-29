pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/*
 * Active keyboard layout, as a two-letter code.
 *
 * Hyprland emits activelayout when it changes, so this probes once at startup
 * and then follows the event rather than polling — a `hyprctl devices` spawn on
 * a timer is a process per tick for something that changes a few times a day.
 */
Singleton {
    id: root

    property string layout: ""

    // "English (US)" and "English (UK)" both want to read EN, so the code comes
    // from the language rather than from the variant in brackets.
    readonly property string code: {
        if (layout.length === 0)
            return "";
        const language = layout.split("(")[0].trim();
        return language.slice(0, 2).toUpperCase();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            // "keyboard-name,Layout Name"
            const parts = event.data.split(",");
            if (parts.length > 1)
                root.layout = parts.slice(1).join(",");
        }
    }

    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const keyboards = JSON.parse(text)?.keyboards ?? [];
                    const main = keyboards.find(k => k.main) ?? keyboards[0];
                    root.layout = main?.active_keymap ?? "";
                } catch (e) {
                    root.layout = "";
                }
            }
        }
    }
}
