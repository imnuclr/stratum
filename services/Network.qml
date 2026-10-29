pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

/*
 * Native NetworkManager via Quickshell.Networking. Replaces what would otherwise
 * be ~1800 lines of nmcli output parsing.
 *
 * Two things the API does not make obvious:
 *  - NetworkDevice.network stays null even on a connected wifi device. The active
 *    network is the connected entry in `networks`.
 *  - Network.signalStrength is 0..1, not 0..100. `strength` below normalises it,
 *    so callers get a percentage like everything else in the shell.
 *
 * The backend also populates asynchronously: for the first second or so after
 * start, devices is empty and wifiEnabled reads false. Every consumer binds, so
 * this resolves itself — but don't read these in Component.onCompleted.
 */
Singleton {
    id: root

    readonly property list<NetworkDevice> devices: Networking.devices?.values ?? []

    // Wired wins when both are up, matching how routing actually behaves.
    readonly property NetworkDevice active: {
        const wired = devices.find(d => d.type === DeviceType.Wired && d.connected);
        if (wired)
            return wired;
        return devices.find(d => d.type === DeviceType.Wifi && d.connected) ?? null;
    }

    readonly property var activeNetwork: (active?.networks?.values ?? []).find(n => n.connected) ?? null

    readonly property bool wifiActive: active?.type === DeviceType.Wifi
    readonly property bool wiredActive: active?.type === DeviceType.Wired
    readonly property bool connected: active !== null

    readonly property bool online: Networking.connectivity === NetworkConnectivity.Full
    readonly property bool portal: Networking.connectivity === NetworkConnectivity.Portal

    readonly property string ssid: activeNetwork?.name ?? ""
    readonly property int strength: Math.round((activeNetwork?.signalStrength ?? 0) * 100)
    readonly property string security: activeNetwork?.security ?? ""
    readonly property int linkSpeed: active?.linkSpeed ?? 0
    readonly property string address: active?.address ?? ""

    readonly property bool wifiEnabled: !!Networking.wifiEnabled
    readonly property bool wifiAvailable: !!Networking.wifiHardwareEnabled

    // Label for the bar and the dashboard's network column.
    readonly property string label: {
        if (wiredActive)
            return active.name;
        if (wifiActive)
            return ssid;
        return "offline";
    }

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = enabled;
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }
}
