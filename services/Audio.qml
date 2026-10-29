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

    // Selectable devices. A node is a device when it isn't a stream; sinks are
    // outputs and anything else carrying audio is an input. Streams are
    // per-application playback and belong in a mixer, not a device list.
    readonly property var nodes: Pipewire.nodes?.values ?? []
    readonly property list<PwNode> sinks: nodes.filter(n => !n.isStream && n.isSink)
    readonly property list<PwNode> sources: nodes.filter(n => !n.isStream && !n.isSink && n.audio)

    function deviceName(node) {
        return node?.description ?? node?.nickname ?? node?.name ?? "";
    }

    function setSink(node) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setSource(node) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    function setSourceVolume(level) {
        if (!source?.ready || !source?.audio)
            return;
        source.audio.muted = false;
        source.audio.volume = Math.max(0, Math.min(1, level));
    }

    readonly property string settingsApp: Launch.firstOf(["pwvucontrol", "pavucontrol", "helvum"])

    function openSettings() {
        Launch.run(settingsApp);
    }

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

    function setMuted(value) {
        if (root.sink?.audio)
            root.sink.audio.muted = value;
    }

    function toggleMuted() {
        if (sink?.ready && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function toggleSourceMuted() {
        if (source?.ready && source?.audio)
            source.audio.muted = !source.audio.muted;
    }

    // Tracking only the defaults leaves every other device's description empty,
    // so the picker would render a list of blanks.
    PwObjectTracker {
        objects: [...root.sinks, ...root.sources]
    }
}
