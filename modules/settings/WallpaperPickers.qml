import Quickshell

Variants {
    model: Quickshell.screens

    WallpaperPicker {
        required property ShellScreen modelData

        monitor: modelData
    }
}
