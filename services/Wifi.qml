pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.services

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

    /*
     * A known network is brought up from its stored profile. It used to be
     * handed an empty passphrase instead, which NetworkManager took as a new
     * secret to try rather than the saved one, so picking another network
     * did nothing. An open network needs no secret at all.
     */
    function connect(network) {
        if (!network)
            return;
        console.info(`[wifi] connecting to ${network.name} (known=${network.known})`);
        if (network.known || !root.isSecure(network))
            network.connect();
        else
            root.requestPassword(network);
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

    /*
     * The network's own disconnect, which takes down just that connection and
     * leaves a wired link up. It used to be `nmcli connection down id <name>`,
     * but the name shown is the network's, and the saved connection is often
     * called something else ("TonbridgeSchool" against "Tonbridge-WiFi"), so
     * nothing went down.
     */
    function disconnect() {
        root.activeNetwork?.disconnect();
    }

    function openSettings() {
        Launch.run(settingsApp);
    }

    // Why a connection did not come up, for the log.
    Instantiator {
        model: root.device?.networks ?? null

        delegate: Connections {
            required property var modelData

            target: modelData

            function onConnectionFailed(reason) {
                console.warn(`[wifi] could not connect to ${modelData.name}: ${reason}`);
            }
        }
    }

    /*
     * How fast the link to the connected network is running, in Mbit/s, each
     * way: what the card and the access point have settled on, not a speed
     * test. Read from `iw` every few seconds, only while a network list is on
     * screen. -1 when there is nothing to read.
     */
    property real rxRate: -1
    property real txRate: -1

    Timer {
        running: root.scanning && !!root.activeNetwork && (root.device?.name ?? "").length > 0
        repeat: true
        triggeredOnStart: true
        interval: 3000
        onTriggered: {
            if (!link.running)
                link.running = true;
        }
        onRunningChanged: {
            if (!running) {
                root.rxRate = -1;
                root.txRate = -1;
            }
        }
    }

    Process {
        id: link

        command: ["iw", "dev", root.device?.name ?? "", "link"]

        stdout: StdioCollector {
            onStreamFinished: {
                const rx = text.match(/rx bitrate:\s*([\d.]+)/);
                const tx = text.match(/tx bitrate:\s*([\d.]+)/);
                root.rxRate = rx ? parseFloat(rx[1]) : -1;
                root.txRate = tx ? parseFloat(tx[1]) : -1;
            }
        }
    }

    // The backend reports no "scan finished" signal, so the spinner runs for a
    // fixed window rather than claiming to know when results are complete.
    Timer {
        id: scanSettle

        interval: 4000
        onTriggered: root.rescanning = false
    }
}
