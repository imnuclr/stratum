pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

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

    function setEnabled(value) {
        if (adapter)
            adapter.enabled = value;
    }

    function toggle() {
        setEnabled(!enabled);
    }
}
