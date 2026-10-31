pragma Singleton

import QtQuick
import Quickshell

/*
 * Every setting by name, for the search box in settings: which page it is on,
 * its title as the page shows it, and the other words someone might reach for
 * — "dark" finds Mode, "wifi password" finds Wi-Fi, "hz" finds Refresh rate.
 *
 * Matching forgives spelling: a word within a letter or two of one listed
 * here still counts, and letters typed in order count a little.
 */
Singleton {
    id: root

    readonly property var entries: [
        // wallpaper
        ["wallpaper", "Wallpaper", "background picture photo image desktop backdrop"],
        ["wallpaper", "Wallpaper folder", "directory folder location path pictures images change"],
        ["wallpaper", "Dots", "dotted halftone dot matrix pattern grid look style"],
        ["wallpaper", "Depth", "parallax drift cutout rembg 3d subject move"],
        // appearance
        ["appearance", "Mode", "dark light theme night day black white mode"],
        ["appearance", "Colours from wallpaper", "matugen material you dynamic palette colors tint scheme generate"],
        ["appearance", "Accent", "accent highlight colour color tint red emphasis"],
        ["appearance", "Custom colour", "custom color hex picker hue any rgb"],
        ["appearance", "Terminal", "terminal kitty alacritty foot ghostty colours theme apps"],
        ["appearance", "Spotify", "spotify spicetify theme colours apps music"],
        ["appearance", "Vesktop / Discord", "discord vesktop vencord theme colours apps"],
        ["appearance", "GTK apps", "gtk libadwaita gnome apps accent theme"],
        ["appearance", "Borders and glow", "window border outline glow shadow colour active hyprland"],
        ["appearance", "Blur", "blur frosted glass transparency windows hyprland intensity strength effects"],
        ["appearance", "24-hour time", "clock time format 12 hour 24 hour am pm military"],
        // motion
        ["motion", "Animation speed", "animation speed motion fast slow reduce transitions effects"],
        ["motion", "Fine tune", "animation percent speed exact"],
        ["motion", "Cross-fade", "wallpaper fade transition duration"],
        // bar
        ["bar", "Show the bar", "bar panel taskbar hide show dock"],
        ["bar", "Shape", "column strip vertical horizontal orientation"],
        ["bar", "Edge", "position left right top bottom side"],
        ["bar", "Width", "size thickness bar width height"],
        ["bar", "Tray", "system tray icons background apps hide hover status notifier"],
        ["bar", "Margin", "gap spacing padding edge distance"],
        ["bar", "Layout", "islands thirds edges arrangement"],
        ["bar", "Workspaces", "workspace count desktops virtual dots"],
        // widgets
        ["widgets", "Show widgets", "desktop widgets clock weather gadgets"],
        ["widgets", "Hide behind windows", "covered hide windows overlap"],
        ["widgets", "Arrange", "edit move resize add widgets layout"],
        ["widgets", "Reset every display", "reset widgets default layout"],
        // launcher
        ["launcher", "Files", "file search find documents plocate locate"],
        ["launcher", "Recent files", "recent history documents opened"],
        ["launcher", "Calculator", "calculator maths math sums calc"],
        ["launcher", "Search the web", "web internet browser google search online"],
        ["launcher", "Search engine", "duckduckgo google brave startpage engine"],
        ["launcher", "Rank by use", "frequency ranking learning forget history apps"],
        ["launcher", "Shortcut", "launcher spotlight key shortcut super space open"],
        // weather
        ["weather", "Location", "weather location city town map where forecast place ip"],
        ["weather", "Units", "celsius fahrenheit temperature units metric imperial"],
        // notifications
        ["notifications", "Do not disturb", "dnd silence quiet mute focus notifications"],
        ["notifications", "Toast duration", "popup notification time seconds how long timeout"],
        ["notifications", "Try it", "test notification preview send"],
        ["notifications", "Clear everything", "clear dismiss all notifications"],
        // displays
        ["displays", "Resolution", "resolution pixels size screen display monitor 4k 1080p 1440p"],
        ["displays", "Refresh rate", "refresh rate hz hertz fps frame 60 120 144 165"],
        ["displays", "Scale", "scale scaling zoom size text bigger smaller hidpi dpi"],
        ["displays", "Brightness", "brightness dim bright backlight screen light"],
        ["displays", "Arrangement", "arrange position monitors layout move multiple screens"],
        ["displays", "Night light", "night light blue light warm filter sunset redshift"],
        ["displays", "Dark mode", "dark mode theme"],
        ["displays", "Bar edge", "monitor bar edge position per screen"],
        // sound
        ["sound", "Volume", "volume loudness audio speaker sound level output"],
        ["sound", "Mute", "mute silence sound off quiet"],
        ["sound", "Step", "volume step keys increment"],
        ["sound", "Show the level when it changes", "osd overlay popup indicator volume brightness"],
        ["sound", "Output device", "speakers headphones output device play through audio"],
        ["sound", "Microphone level", "microphone mic input gain level recording"],
        ["sound", "Mute the microphone", "microphone mic mute input"],
        ["sound", "Per-app volume and more", "mixer pavucontrol app volume"],
        // network
        ["network", "Wi-Fi", "wifi wireless wlan internet network password connect join ssid"],
        ["network", "Airplane mode", "airplane flight mode radios offline"],
        ["network", "VPN", "vpn wireguard tunnel private"],
        ["network", "Wired", "ethernet cable wired lan"],
        ["network", "Status", "ip address connection online internet status"],
        // bluetooth
        ["bluetooth", "Bluetooth", "bluetooth bt wireless devices"],
        ["bluetooth", "Look for new devices", "pair pairing discover scan add device headphones earbuds"],
        // power
        ["power", "Power profile", "power profile eco balanced performance battery saver mode"],
        ["power", "Saving energy", "battery life save energy eco low power savers"],
        ["power", "On the lock screen", "lock screen shut down restart reboot log out sleep power buttons"],
        ["power", "Keep awake", "caffeine idle sleep screen off awake inhibit"],
        ["power", "Battery", "battery charge percentage charging time remaining"],
        // keybinds
        ["keybinds", "Keybinds", "keyboard shortcuts hotkeys keys bindings binds"],
        // about
        ["about", "About", "system information version hardware specs computer hostname"],
        // updates
        ["updates", "Check automatically", "update upgrade version new release automatic"],
        ["updates", "How often", "update check frequency hourly daily interval"],
        // advanced
        ["advanced", "Diagnostic tracing", "debug logging trace logs"],
        ["advanced", "Settings folder", "config configuration files folder"],
        ["advanced", "Your name", "name greeting user username"],
        ["advanced", "Profile picture", "avatar face photo picture profile account user image"]
    ]

    // The pages themselves, as [label, name, icon, words], for the launcher to
    // offer a whole page when that is what was asked for.
    readonly property var pages: [
        ["wallpaper", "Wallpaper", "image", "background picture photo"],
        ["appearance", "Appearance", "contrast", "dark light theme colour color accent clock 24 hour"],
        ["motion", "Motion", "motion", "animation speed reduce fade"],
        ["bar", "Bar", "sidebar", "panel edge column strip workspaces"],
        ["widgets", "Widgets", "grid", "desktop clock weather"],
        ["launcher", "Launcher", "search", "spotlight search apps files calculator web"],
        ["weather", "Weather", "cloud-sun", "weather location city town map forecast temperature units celsius fahrenheit"],
        ["notifications", "Notifications", "bell", "toasts do not disturb dnd"],
        ["displays", "Displays", "monitor", "display monitors screens brightness night light resolution refresh rate hz scale arrange position"],
        ["sound", "Sound", "volume-2", "volume audio speakers headphones microphone mic output input"],
        ["network", "Network", "wifi", "wifi wi-fi ethernet wired vpn airplane internet"],
        ["bluetooth", "Bluetooth", "bluetooth", "devices pair headphones"],
        ["power", "Power", "bolt", "battery profile eco performance sleep caffeine awake"],
        ["keybinds", "Keybinds", "keyboard", "keyboard shortcuts keys hotkeys"],
        ["updates", "Updates", "arrow-down", "update upgrade version new release git pull"],
        ["about", "About", "info", "version system computer hardware"],
        ["advanced", "Advanced", "sliders", "debug config files folder"]
    ]

    // Pages matching a query, best first, as { page, name, icon, score }.
    function searchPages(query, limit) {
        const qs = root.tokens(query);
        if (qs.length === 0)
            return [];
        const out = [];
        for (const [page, name, icon, words] of root.pages) {
            const all = root.tokens(`${name} ${words}`);
            let total = 0;
            let every = true;
            for (const q of qs) {
                const best = Math.max(0, ...all.map(w => root.wordScore(q, w)));
                if (best === 0) {
                    every = false;
                    break;
                }
                total += best;
            }
            if (every)
                out.push({ page: page, name: name, icon: icon, score: total / qs.length });
        }
        return out.sort((a, b) => b.score - a.score).slice(0, limit ?? 4);
    }

    // Letters apart, with a swap of two neighbours counting as one.
    function distance(a, b) {
        if (Math.abs(a.length - b.length) > 2)
            return 9;
        const d = [];
        for (let i = 0; i <= a.length; i++) {
            d.push([i]);
            for (let j = 1; j <= b.length; j++)
                d[i].push(i === 0 ? j : 0);
        }
        for (let i = 1; i <= a.length; i++) {
            for (let j = 1; j <= b.length; j++) {
                const cost = a[i - 1] === b[j - 1] ? 0 : 1;
                d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost);
                if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1])
                    d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
            }
        }
        return d[a.length][b.length];
    }

    // How well one typed word matches one known word, 0 for not at all.
    function wordScore(q, w) {
        if (w === q)
            return 100;
        if (w.startsWith(q))
            return 70 + 20 * q.length / w.length;
        if (q.length >= 3 && w.includes(q))
            return 45;
        if (q.length >= 5) {
            // Typos: one wrong letter in a short word, two in a long one,
            // also against the start of a longer word ("brightn" → "brightness").
            const allow = q.length >= 7 ? 2 : 1;
            if (root.distance(q, w) <= allow || root.distance(q, w.slice(0, q.length)) <= allow - (q.length < 7 ? 0 : 1))
                return 55;
        }
        return 0;
    }

    function tokens(text) {
        return String(text).toLowerCase().replace(/colour/g, "color").split(/[^a-z0-9]+/).filter(t => t.length > 0);
    }

    /*
     * Settings for a query, best first, as { page, title, score }. Every word
     * typed has to find something; the score is how well they all did, with
     * matches in the title counting for more than the extra words.
     */
    function search(query, limit) {
        const qs = root.tokens(query);
        if (qs.length === 0)
            return [];
        const out = [];
        for (const [page, title, words] of root.entries) {
            const titleWords = root.tokens(title);
            const extra = root.tokens(`${page} ${words}`);
            let total = 0;
            let all = true;
            for (const q of qs) {
                const t = Math.max(0, ...titleWords.map(w => root.wordScore(q, w)));
                const e = Math.max(0, ...extra.map(w => root.wordScore(q, w))) * 0.8;
                const best = Math.max(t, e);
                if (best === 0) {
                    all = false;
                    break;
                }
                total += best;
            }
            if (all)
                out.push({ page: page, title: title, score: total / qs.length });
        }
        return out.sort((a, b) => b.score - a.score).slice(0, limit ?? 12);
    }
}
