import Quickshell
import qs.config

/*
 * One bar per monitor. Every visual value is read through Config.forMonitor so a
 * display can override height, layout or which islands it shows.
 */
Variants {
    model: Quickshell.screens

    BarWindow {
        required property ShellScreen modelData

        monitor: modelData
    }
}
