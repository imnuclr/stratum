import Quickshell

/*
 * One control centre per monitor; only the one whose monitor is focused is ever
 * open, since Shell tracks a single panel name.
 */
Variants {
    model: Quickshell.screens

    ControlSheet {
        required property ShellScreen modelData

        monitor: modelData
    }
}
