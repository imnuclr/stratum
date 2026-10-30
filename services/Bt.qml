pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services

/*
 * Native BlueZ via Quickshell.Bluetooth. Named Bt rather than Bluetooth so the
 * singleton doesn't shadow the imported module inside its own file.
 */
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property bool discovering: adapter?.discovering ?? false

    readonly property list<BluetoothDevice> devices: Bluetooth.devices?.values ?? []
    readonly property list<BluetoothDevice> connectedDevices: devices.filter(d => d.connected)
    readonly property bool connected: connectedDevices.length > 0

    readonly property string label: {
        if (!enabled)
            return "off";
        if (connectedDevices.length === 1)
            return connectedDevices[0].name;
        if (connectedDevices.length > 1)
            return `${connectedDevices.length} devices`;
        return "on";
    }

    // Paired devices first, then by name, so the list doesn't reshuffle as
    // signal strengths jitter during discovery.
    readonly property list<BluetoothDevice> sorted: [...devices].sort((a, b) =>
        (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    function setDiscovering(value) {
        if (adapter)
            adapter.discovering = value;
    }

    function toggleDiscovering() {
        setDiscovering(!discovering);
    }

    function toggleDevice(device) {
        if (!device)
            return;
        if (device.connected)
            device.disconnect();
        else
            device.connect();
    }

    function forget(device) {
        if (device?.bonded)
            device.forget();
    }

    readonly property string settingsApp: Launch.firstOf(["overskride", "blueman-manager"])

    function openSettings() {
        Launch.run(settingsApp);
    }

    function setEnabled(value) {
        if (adapter)
            adapter.enabled = value;
    }

    function toggle() {
        setEnabled(!enabled);
    }
}
