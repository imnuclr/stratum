import Quickshell

Variants {
    model: Quickshell.screens

    SessionSheet {
        required property ShellScreen modelData

        monitor: modelData
    }
}
