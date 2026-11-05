import Quickshell

/*
 * One full-screen lyrics view per monitor; only the one whose monitor the panel
 * was opened on ever shows, since Shell tracks a single panel name and screen.
 */
Variants {
    model: Quickshell.screens

    LyricsStage {
        required property ShellScreen modelData

        monitor: modelData
    }
}
