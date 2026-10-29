import Quickshell
import qs.config

/*
 * One dashboard per monitor, grown from the centre bar island.
 *
 * Phase 0 scope: proves the Sheet -> Shell -> IPC chain and gives the dot
 * primitives a live surface. Phase 3 replaces the body with the five real
 * columns (time, weather, system, network, media).
 */
Variants {
    model: Quickshell.screens

    DashboardSheet {
        required property ShellScreen modelData

        monitor: modelData
    }
}
