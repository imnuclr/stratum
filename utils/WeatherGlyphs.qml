pragma Singleton

import Quickshell

/*
 * Weather conditions as dot bitmaps, keyed by WMO code.
 *
 * Drawn as outlines rather than filled shapes. A solid blob at this size reads
 * as a smudge and all the conditions collapse into the same one; the hollow
 * version keeps a cloud distinguishable from a sun at seven rows.
 *
 * open-meteo reports around thirty codes; these collapse them to the handful a
 * grid this size can actually tell apart. Each pattern is padded to one width
 * so a row of them lines up without per-glyph nudging.
 */
Singleton {
    id: root

    readonly property var clear: [
        "#..###..#",
        "..#...#..",
        ".#.....#.",
        "##.....##",
        ".#.....#.",
        "..#...#..",
        "#..###..#"
    ]

    readonly property var night: [
        "..####...",
        ".##..##..",
        ".##......",
        ".##......",
        ".##......",
        ".##..##..",
        "..####..."
    ]

    readonly property var partly: [
        ".#.......",
        "#.#......",
        ".#.###...",
        "..#...#..",
        ".#.....#.",
        "#.......#",
        ".#######."
    ]

    readonly property var cloudy: [
        "...###...",
        "..#...#..",
        ".#.....#.",
        "#.......#",
        "#.......#",
        ".#######.",
        "........."
    ]

    readonly property var overcast: [
        "..#####..",
        ".#.....#.",
        "#.......#",
        "#.......#",
        "#.......#",
        ".#######.",
        "........."
    ]

    readonly property var fog: [
        ".#######.",
        ".........",
        "#########",
        ".........",
        ".#######.",
        ".........",
        "..#####.."
    ]

    readonly property var drizzle: [
        "...###...",
        "..#...#..",
        ".#.....#.",
        "#.......#",
        ".#######.",
        ".........",
        "..#.#.#.."
    ]

    readonly property var rain: [
        "...###...",
        "..#...#..",
        ".#.....#.",
        "#.......#",
        ".#######.",
        "..#.#.#..",
        ".#.#.#..."
    ]

    readonly property var snow: [
        "...###...",
        "..#...#..",
        ".#.....#.",
        "#.......#",
        ".#######.",
        "..#.#.#..",
        "...#.#..."
    ]

    readonly property var thunder: [
        "...###...",
        "..#...#..",
        ".#.....#.",
        "#.......#",
        ".#######.",
        "....##...",
        "...##...."
    ]

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
