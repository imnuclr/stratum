pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/*
 * The quick toggles that do not belong to a service of their own.
 *
 * Each carries an `available` flag rather than being hidden outright when its
 * backend is missing: a toggle that silently disappears looks like a bug, while
 * one that is visibly unavailable says what to install.
 */
Singleton {
    id: root

    // Probed once; none of these appear or disappear while the shell runs.
    property bool hasNight: false
    property bool hasRecorder: false

    property bool airplane: false
    property bool caffeine: false
    property bool night: false
    property bool recording: false
    property bool dark: true
    property var vpnConnections: []

    readonly property bool hasVpn: vpnConnections.length > 0
    readonly property bool vpnUp: vpnConnections.some(c => c.active)

    function toggleAirplane() {
        // rfkill reports state per device; "all" covers wifi and bluetooth
        // together, which is what the control means.
        rfkill.command = ["rfkill", root.airplane ? "unblock" : "block", "all"];
        rfkill.running = true;
        root.airplane = !root.airplane;
    }

    function toggleCaffeine() {
        root.caffeine = !root.caffeine;
    }

    function toggleNight() {
        if (!root.hasNight)
            return;
        root.night = !root.night;
        if (root.night) {
            night.command = ["hyprsunset", "-t", "3800"];
            night.running = true;
        } else {
            night.running = false;
        }
    }

    function toggleRecording() {
        if (!root.hasRecorder)
            return;
        if (root.recording) {
            recorder.signal(2);
            root.recording = false;
            return;
        }
        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        recorder.command = ["gpu-screen-recorder", "-w", "screen", "-f", "60",
            "-o", `${Quickshell.env("HOME")}/Videos/Recordings/stratum-${stamp}.mp4`];
        recorder.running = true;
        root.recording = true;
    }

    function toggleDark() {
        root.dark = !root.dark;
        scheme.command = ["gsettings", "set", "org.gnome.desktop.interface",
            "color-scheme", root.dark ? "prefer-dark" : "default"];
        scheme.running = true;
    }

    function toggleVpn() {
        if (!root.hasVpn)
            return;
        const target = root.vpnConnections[0];
        vpn.command = ["nmcli", "connection", root.vpnUp ? "down" : "up", "id", target.name];
        vpn.running = true;
    }

    Process {
        id: rfkill
    }

    Process {
        id: night
    }

    Process {
        id: vpn
    }

    Process {
        id: scheme
    }

    Process {
        id: recorder
    }

    /*
     * Holding an inhibitor process is the whole mechanism: logind releases the
     * lock when the process it belongs to exits, so stopping the process is how
     * caffeine turns off.
     */
    Process {
        running: root.caffeine
        command: ["systemd-inhibit", "--what=idle:sleep", "--who=stratum",
            "--why=Caffeine", "sleep", "infinity"]
    }

    Process {
        running: true
        command: ["sh", "-c",
            "command -v hyprsunset >/dev/null && echo night; " +
            "command -v gpu-screen-recorder >/dev/null && echo recorder"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.hasNight = text.includes("night");
                root.hasRecorder = text.includes("recorder");
            }
        }
    }

    Process {
        running: true
        command: ["rfkill", "-nro", "SOFT"]

        stdout: StdioCollector {
            // Blocked everywhere means airplane mode; partially blocked does not.
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0);
                root.airplane = lines.length > 0 && lines.every(l => l.trim() === "blocked");
            }
        }
    }

    Process {
        running: true
        command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const parts = line.split(":");
                    if (parts.length < 3)
                        continue;
                    if (!/vpn|wireguard/i.test(parts[1]))
                        continue;
                    found.push({ name: parts[0], active: parts[2] === "activated" });
                }
                root.vpnConnections = found;
            }
        }
    }

    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]

        stdout: StdioCollector {
            onStreamFinished: root.dark = text.includes("dark")
        }
    }
}
