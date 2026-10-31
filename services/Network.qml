pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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
    // security is a WifiSecurityType enum, not a string.
    readonly property int securityType: activeNetwork?.security ?? 0
    readonly property string securityName: {
        switch (securityType) {
        case WifiSecurityType.Open:
            return "open";
        case WifiSecurityType.Owe:
            return "OWE";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:
        case WifiSecurityType.Leap:
            return "WEP";
        case WifiSecurityType.WpaPsk:
            return "WPA";
        case WifiSecurityType.Wpa2Psk:
            return "WPA2";
        case WifiSecurityType.Sae:
            return "WPA3";
        case WifiSecurityType.Wpa3SuiteB192:
            return "WPA3-192";
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Wpa2Eap:
            return "enterprise";
        default:
            return "unknown";
        }
    }

    // NetworkDevice.address is the hardware address, not the IPv4 one. The IPv4
    // address isn't exposed by the module, so it comes from `ip` — the one place
    // in this service that leaves the native API, and only because there is no
    // alternative.
    readonly property string mac: active?.address ?? ""
    property string ipv4: ""
    readonly property int linkSpeed: active?.linkSpeed ?? 0

    // The wifi device itself, shared with the Wifi service which owns scanning,
    // the network list and connecting.
    readonly property WifiDevice wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null

    readonly property list<NetworkDevice> wiredDevices: devices.filter(d => d.type === DeviceType.Wired)

    // Wired bring-up and tear-down, like the wifi disconnect, has no native
    // equivalent. Acting on the interface rather than a connection name works for
    // a device whose profile is auto-generated.
    function setWiredConnected(device, value) {
        if (!device?.name)
            return;
        wiredProc.command = ["nmcli", "device", value ? "connect" : "disconnect", device.name];
        wiredProc.running = true;
    }

    Process {
        id: wiredProc
    }

    // Label for the bar and the dashboard's network column.
    readonly property string label: {
        if (wiredActive)
            return active.name;
        if (wifiActive)
            return ssid;
        return "offline";
    }

    /*
     * The address other machines see this one by: the source address the
     * kernel would use to reach the internet. Asking the active device by name
     * read loopback whenever it ran before a device was known, and a Process
     * that is already running ignores being started again, so it stuck there.
     */
    Process {
        id: addrProc

        running: true
        command: ["sh", "-c", "ip -4 -json route get 1.1.1.1 2>/dev/null || ip -4 -json addr show scope global"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const info = JSON.parse(text)?.[0];
                    root.ipv4 = info?.prefsrc ?? info?.addr_info?.[0]?.local ?? "";
                } catch (e) {
                    root.ipv4 = "";
                }
            }
        }
    }

    function readAddress() {
        addrProc.running = false;
        addrProc.running = true;
    }

    Timer {
        // DHCP can change it under a connection that never drops.
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.readAddress()
    }

    onActiveChanged: root.readAddress()
    onActiveNetworkChanged: root.readAddress()
    onOnlineChanged: root.readAddress()


}
