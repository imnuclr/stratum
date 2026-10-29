pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

/*
 * Battery and power profile.
 *
 * This box is a desktop, so `hasBattery` is false and every battery-dependent
 * element in the shell hides itself rather than rendering a fake 100%.
 */
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property bool hasBattery: !!UPower.ready && !!device?.isLaptopBattery

    readonly property real percentage: device?.percentage ?? 0
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: !!UPower.onBattery
    readonly property int timeToEmpty: device?.timeToEmpty ?? 0

    readonly property bool low: hasBattery && onBattery && percentage <= 0.20
    readonly property bool critical: hasBattery && onBattery && percentage <= 0.08

    // power-profiles-daemon. Kept here rather than in its own service because it
    // is the same concern from the user's side: how much power this machine uses.
    property string profile: "balanced"
    readonly property var profiles: ["power-saver", "balanced", "performance"]

    function cycleProfile() {
        const i = root.profiles.indexOf(root.profile);
        root.setProfile(root.profiles[(i + 1) % root.profiles.length]);
    }

    function setProfile(name) {
        if (!profiles.includes(name))
            return;
        setProfileProc.target = name;
        setProfileProc.running = true;
    }

    Process {
        id: setProfileProc

        property string target: ""

        command: ["powerprofilesctl", "set", target]
        onExited: readProfile.running = true
    }

    Process {
        id: readProfile

        running: true
        command: ["powerprofilesctl", "get"]

        stdout: StdioCollector {
            onStreamFinished: root.profile = text.trim()
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 30000
        onTriggered: readProfile.running = true
    }
}
