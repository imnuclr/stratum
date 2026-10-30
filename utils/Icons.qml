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
        "wifi": "M12 19.6h.01M9 15.9a6 6 0 0 1 6 0M5.5 12.2a11 11 0 0 1 13 0M2 8.5a16 16 0 0 1 20 0",
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
        "lock": "M8 10.5V7.5a4 4 0 0 1 8 0v3M5.5 10.5h13v9h-13z",
        "link": "M10.6 13.4a3.5 3.5 0 0 0 5 0l2.4-2.4a3.5 3.5 0 0 0-5-5l-1.2 1.2M13.4 10.6a3.5 3.5 0 0 0-5 0L6 13a3.5 3.5 0 0 0 5 5l1.2-1.2",
        "link-off": "M10.6 13.4a3.5 3.5 0 0 0 4 .6M14.4 9.2a3.5 3.5 0 0 0-4-.6M4.5 4.5l15 15M16 8l2-2a3.5 3.5 0 0 0-5-.3M8 16l-2 2a3.5 3.5 0 0 0 5 .3",
        "trash": "M5 7h14M9.5 7V5h5v2M7.5 7l.9 12.5h7.2L16.5 7",
        "settings": "M10.08 4.85 L10.52 2.11 L13.48 2.11 L13.92 4.85 L15.70 5.59 L17.95 3.96 L20.04 6.05 L18.41 8.30 L19.15 10.08 L21.89 10.52 L21.89 13.48 L19.15 13.92 L18.41 15.70 L20.04 17.95 L17.95 20.04 L15.70 18.41 L13.92 19.15 L13.48 21.89 L10.52 21.89 L10.08 19.15 L8.30 18.41 L6.05 20.04 L3.96 17.95 L5.59 15.70 L4.85 13.92 L2.11 13.48 L2.11 10.52 L4.85 10.08 L5.59 8.30 L3.96 6.05 L6.05 3.96 L8.30 5.59Z M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z",
        "scan": "M20 12a8 8 0 1 1-2.4-5.7M20.5 4.5v4h-4",
        "headphones": "M4.5 14.5v-2.5a7.5 7.5 0 0 1 15 0v2.5M4.5 14h3v5.5h-1.5a1.5 1.5 0 0 1-1.5-1.5zM19.5 14h-3v5.5h1.5a1.5 1.5 0 0 0 1.5-1.5z",
        "mic": "M12 4.5a2.5 2.5 0 0 1 2.5 2.5v4a2.5 2.5 0 0 1-5 0V7A2.5 2.5 0 0 1 12 4.5M6.5 11a5.5 5.5 0 0 0 11 0M12 16.5V20",
        "check": "M5.5 12.5l4.5 4.5L18.5 7.5",
        "chevron-down": "m6 9.5 6 6 6-6",
        "chevron-left": "m14.5 6-6 6 6 6",
        "app": "M4.5 4.5h6v6h-6zM13.5 4.5h6v6h-6zM4.5 13.5h6v6h-6zM13.5 13.5h6v6h-6z",
        "terminal": "m5 7.5 4 4.5-4 4.5M12.5 16.5H19",
        "sun": "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.6 5.6 7 7M17 17l1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4",
        "moon": "M20 14.5A8.5 8.5 0 0 1 9.5 4a8.5 8.5 0 1 0 10.5 10.5",
        "arrow-down": "M12 5v14M6.5 13.5 12 19l5.5-5.5",
        "arrow-up": "M12 19V5M6.5 10.5 12 5l5.5 5.5",
        "play": "M8 5.5v13l11-6.5z",
        "pause": "M9 5.5h2.5v13H9zM14.5 5.5H17v13h-2.5z",
        "skip-back": "M18 5.5v13L8.5 12zM6.5 5.5H8v13H6.5z",
        "skip-forward": "M6 5.5v13L15.5 12zM16 5.5h1.5v13H16z",
        "cloud": "M7.5 18.5h9a3.8 3.8 0 0 0 .4-7.6 5.4 5.4 0 0 0-10.3 1.3 3.3 3.3 0 0 0 .9 6.3",
        "cloud-sun": "M4 9.5a3.2 3.2 0 0 1 6 1M7 4v1.6M3 8h1.6M10.4 5.1 9.3 6.2M9.5 18.5h7a3.5 3.5 0 0 0 .3-7 5 5 0 0 0-9.5 1.2 3 3 0 0 0 .8 5.8",
        "cloud-rain": "M7.5 15.5h9a3.8 3.8 0 0 0 .4-7.6A5.4 5.4 0 0 0 6.6 9.2a3.3 3.3 0 0 0 .9 6.3M8.5 18.5l-1 2.5M12.5 18.5l-1 2.5M16.5 18.5l-1 2.5",
        "cloud-snow": "M7.5 15.5h9a3.8 3.8 0 0 0 .4-7.6A5.4 5.4 0 0 0 6.6 9.2a3.3 3.3 0 0 0 .9 6.3M8.5 19h.01M12 20.5h.01M15.5 19h.01",
        "cloud-lightning": "M7.5 15.5h9a3.8 3.8 0 0 0 .4-7.6A5.4 5.4 0 0 0 6.6 9.2a3.3 3.3 0 0 0 .9 6.3M13 17l-2.5 3.5h3L11 24",
        "cloud-fog": "M7.5 14.5h9a3.8 3.8 0 0 0 .4-7.6A5.4 5.4 0 0 0 6.6 8.2a3.3 3.3 0 0 0 .9 6.3M5 18h14M7.5 21h9",
        "battery-vertical": "M9.5 7.5h5v13h-5zM10.5 5.5h3v2h-3",
        "power": "M12 3.5v8M7.8 6.4a7 7 0 1 0 8.4 0",
        "bell": "M12 4a5.5 5.5 0 0 1 5.5 5.5v4l1.5 2.5h-14L6.5 13.5v-4A5.5 5.5 0 0 1 12 4M10 18.5a2 2 0 0 0 4 0",
        "bell-off": "M8 6.3A5.5 5.5 0 0 1 17.5 9.5v4l1.5 2.5H9M6.6 11a5.5 5.5 0 0 0-.1 2.5L5 16h3M10 18.5a2 2 0 0 0 4 0M3 3l18 18",
        "bolt": "M13 3 7 13h4l-1 8 6-10h-4z",
        "brightness": "M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6 7.4 7.4M16.6 16.6l1.8 1.8M18.4 5.6l-1.8 1.8M7.4 16.6l-1.8 1.8",
        "file": "M6 3h8l4 4v14H6zM14 3v4h4M9 12h6M9 16h6",
        "folder": "M3 6.5a1.5 1.5 0 0 1 1.5-1.5H9l2 2.5h8.5A1.5 1.5 0 0 1 21 9v9.5a1.5 1.5 0 0 1-1.5 1.5h-15A1.5 1.5 0 0 1 3 18.5z",
        "image": "M4 4h16v16H4zM4 16l5-5 4 4 2.5-2.5L20 17M15.5 8.5h.01",
        "calc": "M6 3h12v18H6zM9 7h6M9 11h.01M12 11h.01M15 11h.01M9 14.5h.01M12 14.5h.01M15 14.5h.01M9 18h.01M12 18h.01M15 18h.01",
        "globe": "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0zM3 12h18M12 3c2.5 2.5 3.5 5.5 3.5 9s-1 6.5-3.5 9c-2.5-2.5-3.5-5.5-3.5-9s1-6.5 3.5-9z",
        "search": "M10.5 17a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13zM15.5 15.5 20 20",
        "close": "M6.5 6.5l11 11M17.5 6.5l-11 11",
        "airplane": "M10.5 3.5a1.5 1.5 0 0 1 3 0v5l7 4v2.5l-7-2v4l2.5 2v2l-4-1.2-4 1.2v-2l2.5-2v-4l-7 2V12.5l7-4z",
        "coffee": "M4.5 8.5h12v6a4 4 0 0 1-4 4h-4a4 4 0 0 1-4-4zM16.5 10.5h1.8a2.5 2.5 0 0 1 0 5h-1.8M7 3.5v2M10.5 3.5v2M14 3.5v2",
        "record": "M12 7.5a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9",
        "shield": "M12 3.5 5 6v5.5c0 4 3 7.3 7 9 4-1.7 7-5 7-9V6z",
        "contrast": "M12 3.5a8.5 8.5 0 1 0 0 17 8.5 8.5 0 0 0 0-17M12 3.5v17"
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
    /*
     * Tray items hand over a themed icon name, a pixmap, or — for apps that
     * should know better — an absolute file path pushed through the themed-icon
     * provider as `image://icon//usr/...`. That last form resolves to nothing and
     * leaves a silent gap in the row, so rewrite it to a file URL.
     */
    function trayIcon(icon) {
        if (!icon)
            return "";
        const marker = "image://icon/";
        if (icon.startsWith(marker)) {
            const rest = icon.slice(marker.length);
            if (rest.startsWith("/"))
                return `file://${rest}`;
        }
        return icon;
    }

    // BlueZ reports freedesktop icon names; map the ones that actually show up.
    function bluetoothDevice(name) {
        if (!name)
            return "bluetooth";
        if (name.startsWith("audio-card") || name.startsWith("audio-speakers"))
            return "volume-2";
        if (name.startsWith("audio-input") || name.includes("microphone"))
            return "mic";
        if (name.startsWith("audio-"))
            return "headphones";
        if (name.startsWith("input-") || name.startsWith("phone") || name.startsWith("computer"))
            return "app";
        return "bluetooth";
    }

    // The stroke icon for a WMO weather code, as open-meteo reports it.
    function weather(code, day) {
        if (code === 0)
            return day ? "sun" : "moon";
        if (code === 1 || code === 2)
            return day ? "cloud-sun" : "cloud";
        if (code === 45 || code === 48)
            return "cloud-fog";
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82))
            return "cloud-rain";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return "cloud-snow";
        if (code >= 95)
            return "cloud-lightning";
        return "cloud";
    }

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
