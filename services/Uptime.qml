pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// How long the machine has been up, read from /proc/uptime.
Singleton {
    id: root

    property real seconds: 0

    // "3d 14h", "14h 06m", or "6m" — the two units that say the most.
    readonly property string brief: {
        const s = Math.max(0, root.seconds);
        const d = Math.floor(s / 86400);
        const h = Math.floor(s % 86400 / 3600);
        const m = Math.floor(s % 3600 / 60);
        if (d > 0)
            return `${d}d ${h}h`;
        if (h > 0)
            return `${h}h ${String(m).padStart(2, "0")}m`;
        return `${m}m`;
    }

    FileView {
        id: file

        path: "/proc/uptime"
        onLoaded: root.seconds = parseFloat(file.text().split(" ")[0]) || 0
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 30000
        onTriggered: file.reload()
    }
}
