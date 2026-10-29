pragma Singleton

import QtQuick
import Quickshell

/*
 * Stroke icon paths, authored on a 24x24 grid with a 1.7 stroke so they sit
 * consistently beside 10px caps labels. Glyph renders them; nothing else should
 * read `paths` directly.
 *
 * Level-based names (wifi-2, battery-3) are picked by the `level` helpers rather
 * than by callers doing arithmetic at the use site.
 */
Singleton {
    id: root

    readonly property var paths: ({
        "wifi-dot": "M12 19.6h.01",
        "wifi-arc1": "M9 15.9a6 6 0 0 1 6 0",
        "wifi-arc2": "M5.5 12.2a11 11 0 0 1 13 0",
        "wifi-arc3": "M2 8.5a16 16 0 0 1 20 0",
        "wifi-off": "M2 8.5a16 16 0 0 1 6.5-3.9M15.5 5a16 16 0 0 1 6.5 3.5M5.5 12.2a11 11 0 0 1 3-2M12 19.6h.01M3 3l18 18",
        "ethernet": "M8 3.5h8v5H8zM12 8.5v4M4 17.5h4v3H4zM10 17.5h4v3h-4zM16 17.5h4v3h-4zM6 17.5v-2.5h12v2.5M12 15v-2.5",
        "bluetooth": "M7 7.5 17 16.5 12 21V3l5 4.5L7 16.5",
        "bluetooth-off": "m7 7.5 10 9L12 21v-6M12 9V3l5 4.5-3 2.7M3 3l18 18",
        "volume-0": "M4 9.5h3.5L12 5.5v13L7.5 14.5H4z",
        "volume-1": "M4 9.5h3.5L12 5.5v13L7.5 14.5H4zM16 9.2a4 4 0 0 1 0 5.6",
        "volume-2": "M4 9.5h3.5L12 5.5v13L7.5 14.5H4zM16 9.2a4 4 0 0 1 0 5.6M18.6 6.8a7.5 7.5 0 0 1 0 10.4",
        "volume-mute": "M4 9.5h3.5L12 5.5v13L7.5 14.5H4zM16.5 9.5l5 5M21.5 9.5l-5 5",
        "mic-off": "M9 5.5a3 3 0 0 1 6 0V11M18 11.5a6 6 0 0 1-8.6 5.4M6 11.5a6 6 0 0 0 3 5.2M12 20v2M3 3l18 18",
        "battery-charging": "M2.5 8.5h11.5M2.5 15.5h11.5M2.5 8.5A1.5 1.5 0 0 0 1 10v4a1.5 1.5 0 0 0 1.5 1.5M16.5 8.5A1.5 1.5 0 0 1 18 10v4a1.5 1.5 0 0 1-1.5 1.5M20 10.5v3M11 7l-3 5h3l-3 5",
        "chevron-down": "m6 9.5 6 6 6-6",
        "chevron-left": "m14.5 6-6 6 6 6",
        "app": "M4.5 4.5h6v6h-6zM13.5 4.5h6v6h-6zM4.5 13.5h6v6h-6zM13.5 13.5h6v6h-6z",
        "terminal": "m5 7.5 4 4.5-4 4.5M12.5 16.5H19"
    })

    // The battery outline is drawn once and filled by Glyph, so it isn't a path.
    readonly property string batteryShell: "M2.5 8.5h14a1.5 1.5 0 0 1 1.5 1.5v4a1.5 1.5 0 0 1-1.5 1.5h-14A1.5 1.5 0 0 1 1 14v-4a1.5 1.5 0 0 1 1.5-1.5zM20 10.5v3"

    function path(name) {
        return paths[name] ?? "";
    }

    function has(name) {
        return paths[name] !== undefined;
    }

    // 0..1 volume to one of three speaker glyphs.
    function volume(level, muted) {
        if (muted)
            return "volume-mute";
        if (level >= 0.5)
            return "volume-2";
        if (level > 0)
            return "volume-1";
        return "volume-0";
    }
}
