pragma Singleton

import Quickshell

/*
 * Weather conditions as dot bitmaps, keyed by WMO code.
 *
 * open-meteo reports around thirty codes; these collapse them to the handful a
 * ten-by-seven grid can actually tell apart. Each pattern is padded to the same
 * width so a row of them lines up without per-glyph nudging.
 */
Singleton {
    id: root

    readonly property var clear: [
        "....##....",
        "..######..",
        ".########.",
        ".########.",
        ".########.",
        "..######..",
        "....##...."
    ]

    readonly property var night: [
        "...####...",
        "..####....",
        ".####.....",
        ".####.....",
        ".####.....",
        "..####....",
        "...####..."
    ]

    readonly property var partly: [
        ".##.......",
        "####......",
        ".##.####..",
        "...######.",
        "..########",
        "..#######.",
        ".........."
    ]

    readonly property var cloudy: [
        "....####..",
        "..########",
        ".#########",
        "##########",
        ".########.",
        "..######..",
        ".........."
    ]

    readonly property var overcast: [
        "..######..",
        ".########.",
        "##########",
        "##########",
        ".########.",
        "..######..",
        ".........."
    ]

    readonly property var fog: [
        "..######..",
        "..........",
        ".########.",
        "..........",
        "..######..",
        "..........",
        ".########."
    ]

    readonly property var drizzle: [
        "...####...",
        ".########.",
        "##########",
        ".########.",
        "..........",
        "..#.#.#...",
        ".........."
    ]

    readonly property var rain: [
        "...####...",
        ".########.",
        "##########",
        ".########.",
        "..#..#..#.",
        ".#..#..#..",
        "#..#..#..."
    ]

    readonly property var snow: [
        "...####...",
        ".########.",
        "##########",
        ".########.",
        "..#..#..#.",
        "..........",
        "...#..#..."
    ]

    readonly property var thunder: [
        "...####...",
        ".########.",
        "##########",
        ".########.",
        "....##....",
        "...##.....",
        "..####...."
    ]

    /*
     * Outline icon names for the same codes. The forecast row uses line art
     * rather than dot bitmaps: at the size those sit, a seven-row grid cannot
     * distinguish rain from snow, and four unreadable glyphs in a row are worse
     * than four legible ones in a different idiom.
     */
    function outlineForCode(code, day) {
        if (code < 0)
            return "cloud";
        if (code === 0)
            return day ? "sun" : "moon";
        if (code <= 2)
            return "cloud-sun";
        if (code === 3)
            return "cloud";
        if (code <= 48)
            return "cloud-fog";
        if (code <= 57)
            return "cloud-rain";
        if (code <= 67)
            return "cloud-rain";
        if (code <= 77)
            return "cloud-snow";
        if (code <= 82)
            return "cloud-rain";
        if (code <= 86)
            return "cloud-snow";
        return "cloud-lightning";
    }

    function forCode(code, day) {
        if (code < 0)
            return root.overcast;
        if (code === 0)
            return day ? root.clear : root.night;
        if (code <= 2)
            return root.partly;
        if (code === 3)
            return root.cloudy;
        if (code <= 48)
            return root.fog;
        if (code <= 57)
            return root.drizzle;
        if (code <= 67)
            return root.rain;
        if (code <= 77)
            return root.snow;
        if (code <= 82)
            return root.rain;
        if (code <= 86)
            return root.snow;
        return root.thunder;
    }
}
