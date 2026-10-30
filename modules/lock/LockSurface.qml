import Quickshell.Wayland

// One per screen, made by the session lock. The screen shows the shared auth
// state, so typing on either monitor fills the box on both.
WlSessionLockSurface {
    id: root

    required property var auth

    color: "black"

    LockScreen {
        anchors.fill: parent
        auth: root.auth
    }
}
