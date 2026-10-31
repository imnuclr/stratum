import Quickshell

Variants {
    model: Quickshell.screens

    WallpaperMenu {
        required property ShellScreen modelData

        monitor: modelData
    }
}
