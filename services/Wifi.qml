pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

/*
 * Wi-Fi management: the radio, the networks in range, and connecting to them.
 *
 * Split out of Network, which had grown to cover both the connection status the
 * bar reads and the whole picker surface the popout drives. Network still owns
 * "what am I connected to"; this owns "what could I connect to, and how".
 */
Singleton {
    id: root

    /*
     * Resolved here rather than read from the Network singleton. This file needs
     * Quickshell.Networking for WifiDevice and WifiSecurityType, and that module
     * exports a type called Network which shadows the service singleton of the
     * same name — so `Network.wifiDevice` from in here is silently undefined and
     * the network list comes back empty. See DESIGN.md §13.17.
     */
    readonly property WifiDevice device: (Networking.devices?.values ?? [])
        .find(d => d.type === DeviceType.Wifi) ?? null

    readonly property var activeNetwork: (device?.networks?.values ?? []).find(n => n.connected) ?? null

    readonly property bool enabled: !!Networking.wifiEnabled
    readonly property bool available: !!Networking.wifiHardwareEnabled

    // Strongest first, connected pinned to the top. Capped because a popout list
    // that scrolls is worse than one showing the networks you would actually pick.
    readonly property list<WifiNetwork> networks: [...(device?.networks?.values ?? [])]
        .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
        .slice(0, 7)

    readonly property int count: device?.networks?.values?.length ?? 0

    // Driven by whoever is showing a network list, so the radio isn't scanning
    // continuously in the background.
    property bool scanning: false
    // Distinct from `scanning`: true only while an explicit rescan is in flight.
    // Binding the button's busy state to `scanning` left it pulsing for as long
    // as the popout was open, since opening it enables the scanner.
    property bool rescanning: false

    // Set while a secured unknown network waits on a passphrase. The popout binds
    // to it rather than owning it, so dismissing and reopening keeps the prompt.
    property var pendingNetwork: null

    readonly property string settingsApp: Launch.firstOf(["nm-connection-editor", "iwgtk"])

    function setEnabled(value) {
        Networking.wifiEnabled = value;
    }

    function toggle() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function setScanning(value) {
        if (!device)
            return;
        device.scannerEnabled = value;
        root.scanning = value;
        if (!value)
            root.rescanning = false;
    }

    function rescan() {
        if (!device)
            return;
        device.scannerEnabled = false;
        device.scannerEnabled = true;
        root.scanning = true;
        root.rescanning = true;
        scanSettle.restart();
    }

    function securityOf(network) {
        return network?.security ?? WifiSecurityType.Open;
    }

    function isSecure(network) {
        return root.securityOf(network) !== WifiSecurityType.Open;
    }

    function needsPassword(network) {
        return !!network && !network.known && root.isSecure(network);
    }

    // A known network has a stored profile, so an empty secret is enough.
    function connect(network) {
        if (network)
            network.connectWithPsk("");
    }

    function toggleNetwork(network) {
        if (network?.connected)
            root.disconnect();
        else
            root.connect(network);
    }

    function requestPassword(network) {
        root.pendingNetwork = network;
    }

    function cancelPassword() {
        root.pendingNetwork = null;
    }

    function submitPassword(psk) {
        if (!root.pendingNetwork)
            return;
        root.pendingNetwork.connectWithPsk(psk);
        root.pendingNetwork = null;
    }

    // Quickshell.Networking exposes no disconnect, so this is one of the two
    // places the networking services leave the native API. Taking the connection
    // down by name rather than the device keeps a wired link up.
    function disconnect() {
        const name = root.activeNetwork?.name ?? "";
        if (!name)
            return;
        disconnectProc.command = ["nmcli", "connection", "down", "id", name];
        disconnectProc.running = true;
    }

    function openSettings() {
        Launch.run(settingsApp);
    }

    Process {
        id: disconnectProc
    }

    // The backend reports no "scan finished" signal, so the spinner runs for a
    // fixed window rather than claiming to know when results are complete.
    Timer {
        id: scanSettle

        interval: 4000
        onTriggered: root.rescanning = false
    }
}
