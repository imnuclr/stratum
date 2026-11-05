pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The whole song, over the whole screen.
 *
 * The widget on the desktop shows the line being sung because that is what a
 * glance wants. This is the other mood: the song as a thing to read along with,
 * with what has been sung above and what is coming below, the current line in
 * the middle where the eye already is, and nothing else on screen.
 *
 * Reached with a key or `stratum ipc call panel toggle lyrics`. Like the
 * wallpaper picker, the window stays mapped whether it is showing or not, so it
 * appears by fading rather than by the compositor animating a new surface.
 *
 * Scrolling is the list following the song, not the person following the list:
 * the current line is pinned to the middle and everything moves past it. The
 * wheel and the arrow keys still work, and a click on any line seeks to it —
 * the words are timed, so they double as a way of moving through the track.
 */
PanelWindow {
    id: root

    required property ShellScreen monitor

    readonly property bool open: Shell.openPanel === "lyrics"
        && (Shell.openScreen.length === 0 ? monitor.name === Shell.fallbackScreen : Shell.openScreen === monitor.name)

    property real shown: root.open ? 1 : 0

    Behavior on shown {
        NumberAnimation {
            duration: Theme.sheetMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft
        }
    }

    // The clock and the fetching only run while this is up. The desktop widget
    // takes its own, so the two never fight over whether anything is watching.
    onOpenChanged: {
        if (open) {
            Lyrics.watch();
            keys.forceActiveFocus();
        } else {
            Lyrics.unwatch();
        }
    }

    Component.onDestruction: {
        if (root.open)
            Lyrics.unwatch();
    }

    readonly property real lineSize: Math.max(26, Math.min(root.monitor.height * 0.042, root.monitor.width * 0.03))

    /*
     * How far out of focus a line is, by how far it is from the one being sung.
     *
     * The single thing that makes a wall of lyrics readable: the eye is told
     * where to look by everything else going soft, rather than by the current
     * line being a slightly different grey. Two lines either side stay sharp
     * enough to read ahead and back, and it falls away past that.
     *
     * Costs a texture per blurred line, so it is a setting, and it only ever
     * applies to the dozen or so lines actually on screen.
     */
    readonly property bool depth: Config.get("lyrics.depth", true)

    function haze(distance) {
        if (!root.depth)
            return 0;
        return Math.min(0.5, Math.max(0, Math.abs(distance) - 1) * 0.09);
    }

    screen: monitor
    visible: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "stratum-lyrics"
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    mask: Region {
        x: 0
        y: 0
        width: root.open ? root.width : 0
        height: root.open ? root.height : 0
    }

    function seekTo(index) {
        const line = Lyrics.lines[index];
        if (!line || !(line.start >= 0) || !(Media.length > 0))
            return;
        // A hair early, so the line clicked is heard from its first word rather
        // than from halfway through it.
        Media.seek(Math.max(0, line.start - 0.15) / Media.length);
        Lyrics.resync(true);
    }

    FocusScope {
        id: keys

        anchors.fill: parent
        focus: true
        opacity: root.shown

        Keys.onEscapePressed: Shell.close()
        Keys.onSpacePressed: Media.playPause()
        Keys.onLeftPressed: root.seekTo(Math.max(0, Lyrics.shownIndex - 1))
        Keys.onRightPressed: root.seekTo(Math.min(Lyrics.lines.length - 1, Lyrics.shownIndex + 1))

        /*
         * The song, and nothing else.
         *
         * Opaque. It was left a hair short of it so the desktop behind would
         * still register as being there, and at a hundredth of its brightness
         * white text on a near-black ground is still perfectly legible as a
         * ghost — the greeting on the wallpaper read straight through the lyric
         * on top of it. Two things to read at once is one too many; this view
         * exists to be the only thing being looked at.
         */
        Rectangle {
            anchors.fill: parent
            color: Theme.bg
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Shell.close()
        }

        // What is playing, at the top, so the words have something to belong to.
        Row {
            id: head

            x: Theme.space(7) * 2.4
            y: Theme.space(7)
            spacing: Theme.space(4)
            transform: Translate {
                y: (1 - root.shown) * -16
            }

            RoundImage {
                anchors.verticalCenter: parent.verticalCenter
                width: 64
                height: 64
                visible: Media.artUrl.length > 0
                source: Media.artUrl
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space(1)

                SectionLabel {
                    text: Lyrics.status === "ready"
                        ? `lyrics · ${Lyrics.provider.replace(/_/g, " ")}${Lyrics.exact ? " · word by word" : " · timed by line"}`
                        : "lyrics"
                    color: Theme.fgBright
                }

                Text {
                    text: Media.title
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }

                SectionLabel {
                    text: Media.artist
                    visible: text.length > 0
                }
            }
        }

        /*
         * The lines. Pinned so the current one sits a little above the middle —
         * dead centre leaves the lines still to come crowded against the bottom
         * of the screen, and what is coming is the half worth more room.
         */
        ListView {
            id: list

            anchors.fill: parent
            anchors.topMargin: head.y + head.height + Theme.space(6)
            anchors.bottomMargin: Theme.space(7) * 2
            anchors.leftMargin: Theme.space(7) * 2.4
            anchors.rightMargin: Theme.space(7) * 2.4

            visible: Lyrics.any
            model: Lyrics.lines
            spacing: Math.round(root.lineSize * 0.42)
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            /*
             * The line being sung is always in the same place and the song moves
             * past it, rather than the line wandering down the screen until the
             * list happens to scroll. A little above the middle: dead centre
             * crowds what is still to come against the bottom of the screen, and
             * what is coming is the half worth more room.
             *
             * The margins are what let the first and last lines reach that
             * place. Without them the list simply stops at its own ends, so the
             * opening of every song played from the top of the screen downwards
             * and the last few lines ran off the bottom.
             */
            currentIndex: Lyrics.shownIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: Math.round(height * 0.34)
            preferredHighlightEnd: Math.round(height * 0.34)
            highlightMoveDuration: Theme.sheetMs * 2
            highlightMoveVelocity: -1
            topMargin: Math.round(height * 0.34)
            bottomMargin: Math.round(height * 0.5)
            cacheBuffer: 2000

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                readonly property int distance: row.index - Lyrics.shownIndex
                // Sounding now — which is not the same as being the line the
                // view is following, because more than one can be.
                readonly property bool current: Lyrics.isActive(row.index)
                readonly property bool sung: !row.current && row.distance < 0
                readonly property bool backing: row.modelData?.background === true

                /*
                 * Where this line sits in the depth of field: 1 for the line
                 * being sung, 0 for every other. Animated rather than switched,
                 * so a line coming into focus arrives instead of appearing —
                 * which is most of what makes the list read as one thing moving
                 * rather than a set of labels changing colour.
                 *
                 * Not called `focus`: Item has one, it is final, and shadowing
                 * it refuses to load at all.
                 */
                property real sharp: row.current ? 1 : 0
                // A line being sung is never out of focus, however far from the
                // anchor it happens to sit.
                property real haze: row.current ? 0 : root.haze(row.distance)

                width: list.width
                height: body.implicitHeight

                Behavior on sharp {
                    NumberAnimation {
                        duration: Theme.sheetMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }
                }

                Behavior on haze {
                    NumberAnimation {
                        duration: Theme.sheetMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }
                }

                // Blurred as a whole, once, rather than per word: the effect is
                // only ever on lines that are not moving.
                layer.enabled: row.haze > 0.01
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: row.haze
                    blurMax: 32
                }

                /*
                 * Every line is the same size.
                 *
                 * The current one was scaled up, which looked right for about a
                 * second and then wrapped: `scale` is a paint-time transform and
                 * the layout does not know about it, so an enlarged two-row line
                 * grew over the lines either side of it. Making the type size
                 * itself animate would lay out every glyph on every frame of the
                 * change.
                 *
                 * It is also not what the thing being imitated does — go and
                 * look: the line being sung is the same size as the rest and is
                 * found by being bright and sharp while everything else is dim
                 * and soft. That is a better signal anyway, because it does not
                 * move the words you are reading.
                 */
                LyricLine {
                    id: body

                    width: parent.width
                    line: row.modelData
                    time: row.current ? Lyrics.at : -1
                    done: row.sung
                    // A backing vocal is a second voice under the lead, so it is
                    // drawn as one: smaller, and never the brightest thing on
                    // screen even while it is being sung.
                    size: row.backing ? root.lineSize * 0.76 : root.lineSize
                    weight: row.backing ? Font.Medium : Font.DemiBold
                    glow: row.current
                    leading: 1.24
                    lit: Qt.alpha(Theme.fg, (row.backing ? 0.26 : 0.34) + (row.backing ? 0.46 : 0.66) * row.sharp)
                    dim: Qt.alpha(Theme.fg, 0.16 + 0.1 * row.sharp)
                    lift: 0.09 * row.sharp
                    swell: 0.06 * row.sharp
                    alignRight: row.modelData?.opposite === true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.seekTo(row.index)
                }
            }
        }

        // Nothing to show, and why not.
        Column {
            anchors.centerIn: parent
            spacing: Theme.space(3)
            visible: !Lyrics.any

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !Media.available ? "Nothing playing"
                    : Lyrics.status === "loading" ? "Looking for the words…"
                    : "No lyrics for this track"
                color: Theme.fgBright
                font.family: Theme.fontUi
                font.pixelSize: 30
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            SectionLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(560, root.width * 0.5)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: Media.available && Lyrics.status !== "loading"
                text: Lyrics.error.length > 0 ? Lyrics.error
                    : !Lyrics.haveKey
                    ? "Word-by-word timing comes from Spicy Lyrics, which needs a free key. Settings → Lyrics, or: stratum ipc call lyrics key <your key>"
                    : "Nothing was found for this track at either source."
            }
        }

        // What the keys do, as the picker has it.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.space(5)
            spacing: Theme.space(5)

            Repeater {
                model: ["← → jump a line", "space play / pause", "click seek", "esc back"]

                SectionLabel {
                    required property string modelData

                    text: modelData
                    color: Theme.fgBright
                }
            }
        }
    }
}
