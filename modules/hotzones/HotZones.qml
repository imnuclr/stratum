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
        id: zones

        required property ShellScreen modelData

        /*
         * Whether another display sits against this one's right edge.
         *
         * The sidebar is reached by running the pointer into that edge, which on
         * the rightmost screen is a wall the pointer stops against. On a screen
         * with a neighbour it is a doorway: every trip to the other display
         * passes through the strip, and the sidebar was opening on each one.
         *
         * Adjacency is what matters, not merely being further right — a display
         * two metres along the desk with a gap in the layout is not somewhere
         * the pointer arrives by crossing this edge. A few pixels of slack
         * covers layouts that are not exactly flush, and the vertical overlap
         * check means a screen stacked above or below does not count.
         */
        readonly property bool neighbourRight: {
            const me = zones.modelData;
            const right = me.x + me.width;
            for (const other of Quickshell.screens) {
                if (other.name === me.name)
                    continue;
                if (Math.abs(other.x - right) > 8)
                    continue;
                // Sharing some height with this one, so the pointer can actually
                // cross between them.
                if (other.y < me.y + me.height && me.y < other.y + other.height)
                    return true;
            }
            return false;
        }

        // A column bar on the right edge is drawn over the strip, so the strip
        // starts just inside it instead.
        readonly property int barInset: Config.get("bar.enabled", true)
            && Config.get("bar.orientation", "vertical") === "vertical"
            && Config.get("bar.edge", "left") === "right"
            ? Config.get("bar.width", 56) + Config.get("bar.margin", 10)
            : 0

        // The deck comes down from the top edge, so it is reached from there.
        HotZone {
            monitor: zones.modelData
            panel: "dashboard"
            edge: "top"
            along: 0.5
            zoneLength: Config.forMonitor(zones.modelData.name, "hotzones.deckLength", 560)
            zoneDepth: Config.forMonitor(zones.modelData.name, "hotzones.deckDepth", 14)
            dwell: Config.forMonitor(zones.modelData.name, "hotzones.deckDwell", 60)
        }

        /*
         * The sidebar: the whole right edge, not two corners.
         *
         * It was reachable from the top-right and bottom-right corners only,
         * which is a target you have to aim for — and aiming for a corner means
         * knowing which corner, when the panel it opens runs the full height of
         * that edge anyway. The edge itself is the obvious thing to point at and
         * cannot be missed, so the two corner zones are now one strip.
         *
         * Shallow, because a full-height strip takes those pixels from every
         * window on the screen rather than from the few hundred a corner covered.
         * It only has to catch a pointer that has run out of screen.
         */
        HotZone {
            monitor: zones.modelData
            panel: "control"
            edge: "right"
            along: 0.5
            inset: zones.barInset
            // The whole edge. Set from the screen rather than configured: a
            // length that is not the screen's height is a gap somewhere.
            zoneLength: zones.modelData.height
            zoneDepth: Config.forMonitor(zones.modelData.name, "hotzones.sideDepth", 6)
            /*
             * How long the pointer has to mean it.
             *
             * On the rightmost screen this only has to reject a flick that
             * glances off the edge, so it is short. With a display on the other
             * side of that edge the same strip is on the route between the two,
             * and the pointer passes through it on every crossing — so it waits
             * long enough that a crossing is over before it elapses, while a
             * pointer parked against the edge still opens the panel. Pressing
             * into the edge to open it is not available there: the pointer
             * leaves for the other screen instead, which is the behaviour asked
             * for.
             */
            dwell: zones.neighbourRight
                ? Config.forMonitor(zones.modelData.name, "hotzones.sideDwellCrossing", 320)
                : Config.forMonitor(zones.modelData.name, "hotzones.sideDwell", 90)
        }
    }
}
