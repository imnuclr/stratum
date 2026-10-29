pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

/*
 * Default sink and source. Native Pipewire — no pactl, no wpctl, no parsing.
 *
 * PwObjectTracker is mandatory: without it the node's `audio` block stays unbound
 * and volume reads as 0 forever.
 */
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? true
    readonly property string sinkName: sink?.description ?? sink?.name ?? ""

    readonly property real sourceVolume: source?.audio?.volume ?? 0
    readonly property bool sourceMuted: source?.audio?.muted ?? true

    readonly property bool ready: sink?.ready ?? false

    function setVolume(level) {
        if (!sink?.ready || !sink?.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, level));
    }

    // Scroll and keybind steps deliberately don't unmute: nudging the level while
    // muted means "set it for when I unmute", not "unmute now".
    function step(delta) {
        if (!sink?.ready || !sink?.audio)
            return;
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + delta));
    }

    function toggleMuted() {
        if (sink?.ready && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleSourceMuted() {
        if (source?.ready && source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
