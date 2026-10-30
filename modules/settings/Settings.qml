import Quickshell

/*
 * One settings panel per monitor; only the one on the focused monitor is ever
 * open, since Shell tracks a single panel name.
 */
Variants {
    model: Quickshell.screens

    SettingsSheet {
        required property ShellScreen modelData

        monitor: modelData
    }
}
