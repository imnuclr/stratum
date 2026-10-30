pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

/*
 * Battery and power profile.
 *
 * A machine with no battery (a desktop) reports `hasBattery` false and every
 * battery-dependent element in the shell hides itself rather than rendering a
 * fake 100%.
 */
Singleton {
    id: root

    // The composite display device is what a battery indicator wants, but it is
    // not flagged as a power supply on most laptops, so `isLaptopBattery` is false
    // on it even with a battery fitted. Ask for a real battery first and accept
    // the display device whenever it reports one present.
    readonly property UPowerDevice realBattery: {
        for (const d of UPower.devices.values) {
            if (d.isLaptopBattery)
                return d;
        }
        return null;
    }
    readonly property UPowerDevice display: UPower.displayDevice
    readonly property UPowerDevice device: display?.isPresent && display.type === UPowerDeviceType.Battery ? display : realBattery
    readonly property bool hasBattery: !!UPower.ready && (!!realBattery || (!!display?.isPresent && display.type === UPowerDeviceType.Battery))

    readonly property real percentage: device?.percentage ?? 0
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: !!UPower.onBattery
    readonly property int timeToEmpty: device?.timeToEmpty ?? 0

    readonly property bool low: hasBattery && onBattery && percentage <= 0.20
    readonly property bool critical: hasBattery && onBattery && percentage <= 0.08

    // power-profiles-daemon, through Quickshell's own binding. Not every machine
    // offers `performance`, so the list is what the daemon actually exposes.
    readonly property string profile: nameOf(PowerProfiles.profile)
    readonly property var profiles: PowerProfiles.hasPerformanceProfile
        ? ["power-saver", "balanced", "performance"]
        : ["power-saver", "balanced"]

    function nameOf(p) {
        if (p === PowerProfile.PowerSaver)
            return "power-saver";
        if (p === PowerProfile.Performance)
            return "performance";
        return "balanced";
    }

    function cycleProfile() {
        const i = root.profiles.indexOf(root.profile);
        root.setProfile(root.profiles[(i + 1) % root.profiles.length]);
    }

    function setProfile(name) {
        if (!profiles.includes(name))
            return;
        PowerProfiles.profile = name === "power-saver" ? PowerProfile.PowerSaver
            : name === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    }
}
