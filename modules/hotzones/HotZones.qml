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
            zoneLength: Config.forMonitor(modelData.name, "hotzones.deckLength", 560)
            zoneDepth: Config.forMonitor(modelData.name, "hotzones.deckDepth", 14)
            dwell: Config.forMonitor(modelData.name, "hotzones.deckDwell", 60)
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
            zoneLength: Config.forMonitor(modelData.name, "hotzones.cornerLength", 320)
            zoneDepth: Config.forMonitor(modelData.name, "hotzones.cornerDepth", 24)
            /*
             * Long enough to reject a pass-through when crossing between
             * monitors, short enough that a deliberate move to the corner
             * registers. 180ms was too long: tracing showed the pointer entering
             * and leaving before the timer elapsed, so the panel never opened at
             * all.
             */
            dwell: Config.forMonitor(modelData.name, "hotzones.cornerDwell", 70)
        }

        // Top right, the corner notifications arrive in, so the page and the
        // toasts share a direction.
        HotZone {
            monitor: modelData
            panel: "notifications"
            edge: "top"
            along: 1
            zoneLength: Config.forMonitor(modelData.name, "hotzones.notifyLength", 320)
            zoneDepth: Config.forMonitor(modelData.name, "hotzones.notifyDepth", 24)
            dwell: Config.forMonitor(modelData.name, "hotzones.notifyDwell", 70)
        }
    
}
}
