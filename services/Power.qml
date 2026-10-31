pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.config
import qs.theme
import qs.services

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
    readonly property bool hasBattery: !!realBattery || (!!display?.isPresent && display.type === UPowerDeviceType.Battery)

    readonly property real percentage: device?.percentage ?? 0
    readonly property bool charging: device?.state === UPowerDeviceState.Charging
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: !!UPower.onBattery
    readonly property int timeToEmpty: device?.timeToEmpty ?? 0
    readonly property int timeToFull: device?.timeToFull ?? 0

    // Seconds as "2h 14m", or just minutes under an hour.
    function formatTime(seconds) {
        const m = Math.round(seconds / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? `${h}h ${m % 60}m` : `${m}m`;
    }

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

    /*
     * What each profile switches off to save energy. Eco and balanced can each
     * have their own set; performance never turns anything off, because it is
     * the one you pick when you want everything. Defaults: eco saves where it
     * costs least to notice, balanced leaves things alone.
     */
    readonly property var savers: [
        { key: "refresh", title: "Lower the refresh rate", detail: "Every screen runs at its slowest rate at its current resolution.", eco: true, balanced: false },
        { key: "effects", title: "No blur or shadows", detail: "Hyprland's heaviest effects on windows.", eco: true, balanced: false },
        { key: "motion", title: "No animations", detail: "Panels and popouts appear without moving.", eco: true, balanced: false },
        { key: "widgets", title: "Slower desktop widgets", detail: "Readings update every few seconds instead of every second.", eco: true, balanced: false },
        { key: "widgetsStop", title: "Stop desktop widgets", detail: "Freezes them, with a pause sign, until you switch back.", eco: false, balanced: false },
        { key: "drift", title: "Still wallpaper", detail: "No drifting between workspaces.", eco: true, balanced: false },
        { key: "dim", title: "Dim the screen", detail: "Down to 40% when switching, if brighter.", eco: true, balanced: false },
        { key: "bluetooth", title: "Turn off Bluetooth", detail: "When switching to this profile.", eco: false, balanced: false }
    ]

    readonly property string profileKey: root.profile === "power-saver" ? "eco" : root.profile

    function saverOn(profileKey, key) {
        if (profileKey === "performance")
            return false;
        const def = root.savers.find(s => s.key === key)?.[profileKey] ?? false;
        return Config.get(`power.save.${profileKey}.${key}`, def);
    }

    function setSaver(profileKey, key, on) {
        if (profileKey !== "performance")
            Config.set(`power.save.${profileKey}.${key}`, on);
    }

    // Whether a saver is in force right now.
    function saving(key) {
        return root.saverOn(root.profileKey, key);
    }

    readonly property bool eco: root.profile === "power-saver"
    property string wantRefresh: ""

    readonly property bool lowRefresh: root.saving("refresh") && Config.get("power.ecoRefresh", true)
    readonly property bool calm: root.saving("motion")
    readonly property bool noEffects: root.saving("effects")

    onLowRefreshChanged: root.applyRefresh(root.lowRefresh ? "min" : "max")

    // At startup the daemon may already be in eco, or the battery appear late;
    // nothing is touched unless the saver is actually on.
    onHasBatteryChanged: {
        if (root.hasBattery && root.lowRefresh)
            root.applyRefresh("min");
    }

    // Animations follow the profile; Theme cannot ask for this itself.
    Binding {
        target: Theme
        property: "calm"
        value: root.calm
    }

    onNoEffectsChanged: Hypr.setEffects(!root.noEffects)

    // One-off savers, done on the way into a profile.
    onProfileKeyChanged: {
        if (root.saving("dim") && Brightness.value > 0.4)
            Brightness.set(0.4);
        if (root.saving("bluetooth"))
            Bt.setEnabled(false);
    }

    Component.onCompleted: {
        if (root.noEffects)
            Hypr.setEffects(false);
        if (root.lowRefresh)
            root.applyRefresh("min");
    }

    function applyRefresh(which) {
        if (!Config.get("power.ecoRefresh", true))
            return;
        root.wantRefresh = which;
        readMonitors.running = true;
    }

    Process {
        id: readMonitors

        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                let monitors = [];
                try {
                    monitors = JSON.parse(text);
                } catch (e) {
                    return;
                }
                for (const m of monitors) {
                    // Rates on offer at the resolution already in use.
                    const rates = [];
                    for (const mode of m.availableModes ?? []) {
                        const hit = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(mode);
                        if (hit && Number(hit[1]) === m.width && Number(hit[2]) === m.height)
                            rates.push(Number(hit[3]));
                    }
                    if (rates.length === 0)
                        continue;
                    const target = root.wantRefresh === "min" ? Math.min(...rates) : Math.max(...rates);
                    if (Math.abs(target - m.refreshRate) < 0.5)
                        continue;
                    Hypr.setMonitorMode(m, m.width, m.height, target.toFixed(2));
                }
            }
        }
    }
}
