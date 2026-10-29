import Quickshell

/*
 * One popout surface per monitor.
 */
Variants {
    model: Quickshell.screens

    BarPopout {
        required property ShellScreen modelData

        monitor: modelData
    }
}
