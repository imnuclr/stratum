import Quickshell

Variants {
    model: Quickshell.screens

    OverviewSheet {
        required property ShellScreen modelData

        monitor: modelData
    }
}
