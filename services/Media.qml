pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

/*
 * The player worth showing. Prefers one that is actually playing, falls back to
 * the most recently seen, so pausing a track doesn't make the widget empty.
 */
Singleton {
    id: root

    readonly property list<MprisPlayer> players: Mpris.players?.values ?? []

    property MprisPlayer remembered: null

    readonly property MprisPlayer active: players.find(p => p.isPlaying) ?? remembered ?? players[0] ?? null

    readonly property bool available: active !== null
    readonly property bool playing: active?.isPlaying ?? false

    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string album: active?.trackAlbum ?? ""
    readonly property string artUrl: active?.trackArtUrl ?? ""
    readonly property string identity: active?.identity ?? ""

    readonly property real length: active?.length ?? 0
    readonly property real position: active?.position ?? 0
    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    readonly property bool canPlay: active?.canTogglePlaying ?? false
    readonly property bool canNext: active?.canGoNext ?? false
    readonly property bool canPrevious: active?.canGoPrevious ?? false

    onPlayingChanged: {
        if (playing)
            remembered = active;
    }

    // A player whose app has quit drops out of Mpris.players; holding a stale
    // reference would keep an empty widget on screen.
    onPlayersChanged: {
        if (remembered && !players.includes(remembered))
            remembered = null;
    }

    readonly property string elapsedLabel: formatTime(position)
    readonly property string lengthLabel: formatTime(length)

    function formatTime(seconds) {
        if (!(seconds > 0))
            return "0:00";
        const total = Math.floor(seconds);
        const h = Math.floor(total / 3600);
        const m = Math.floor(total / 60) % 60;
        const s = total % 60;
        // Hours only when there are any: a three-minute track reading 0:03:12
        // wastes two characters on every row that will ever show it.
        if (h > 0)
            return `${h}:${m < 10 ? "0" : ""}${m}:${s < 10 ? "0" : ""}${s}`;
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }

    function playPause() {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }

    function next() {
        if (active?.canGoNext)
            active.next();
    }

    function previous() {
        if (active?.canGoPrevious)
            active.previous();
    }

    function seek(fraction) {
        if (active && active.length > 0 && active.canSeek)
            active.position = fraction * active.length;
    }

    // Position only advances while something reads it.
    property int watchers: 0

    function watch() {
        root.watchers++;
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
    }

    Timer {
        running: root.watchers > 0 && root.playing
        repeat: true
        interval: 1000
        onTriggered: root.active?.positionChanged()
    }
}
