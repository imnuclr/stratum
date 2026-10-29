import QtQuick
import Quickshell
import qs.config

/*
 * Where the panels are reached from. Each zone names the panel it opens, so
 * adding one is a file here rather than a change to the panel.
 */
Variants {
    model: Quickshell.screens

    Item {
        required property ShellScreen modelData

        // The deck comes down from the top edge, so it is reached from there.
        HotZone {
            monitor: modelData
            panel: "dashboard"
            edge: "top"
            along: 0.5
            zoneLength: Config.forMonitor(modelData.name, "hotzones.deckLength", 520)
            zoneDepth: Config.forMonitor(modelData.name, "hotzones.deckDepth", 6)
        }

        // Bottom right, away from everything: the control centre is the panel you
        // reach for deliberately, not one you want to brush against.
        HotZone {
            monitor: modelData
            panel: "control"
            edge: "bottom"
            along: 1
            // A genuine corner: deep and long enough to catch a flick toward it
            // rather than needing the pointer parked in the last few pixels.
            zoneLength: Config.forMonitor(modelData.name, "hotzones.cornerLength", 260)
            zoneDepth: Config.forMonitor(modelData.name, "hotzones.cornerDepth", 10)
        }
    }
}
