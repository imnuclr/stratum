import Quickshell

/*
 * One notification page per monitor, opened on whichever one it is reached from.
 */
Variants {
    model: Quickshell.screens

    NotificationSheet {
        required property ShellScreen modelData

        monitor: modelData
    }
}
