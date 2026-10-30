pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme
import qs.services

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

    function recordingPath() {
        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        return `${Quickshell.env("HOME")}/Videos/Recordings/stratum-${stamp}.mp4`;
    }

    function stopRecording() {
        // SIGINT, so the recorder finalises the container. Killing it outright
        // leaves an unplayable file.
        recorder.signal(2);
        root.recording = false;
    }

    /*
     * Records the monitor being worked on, named explicitly. `-w screen` picks
     * whichever output the recorder considers first, which on this desk is the
     * secondary one — a recording of the wrong monitor every time. `-w focused`
     * is not the fix either: it demands an explicit -s size and errors out
     * without one, which is why nothing recorded at all. Naming the output gives
     * its native resolution for free.
     */
    function toggleRecording() {
        if (!root.hasRecorder)
            return;
        if (root.recording) {
            root.stopRecording();
            return;
        }
        const output = Hypr.focusedWorkspace?.monitor?.name ?? "screen";
        recorder.command = ["gpu-screen-recorder", "-w", output, "-f", "60",
            "-o", root.recordingPath()];
        recorder.running = true;
        root.recording = true;
    }

    /*
     * Region recording. slurp is asked for the geometry in the recorder's own
     * format rather than its default `X,Y WxH`, so nothing has to reformat it,
     * and reads /dev/null because it blocks on a pipe for candidate regions
     * otherwise.
     */
    function recordRegion() {
        if (!root.hasRecorder || root.recording)
            return;
        recorder.command = ["sh", "-c",
            `mkdir -p "$HOME/Videos/Recordings"; ` +
            `geom=$(slurp -f '%wx%h+%x+%y' </dev/null) || exit 0; ` +
            `exec gpu-screen-recorder -w region -region "$geom" -f 60 -o '${root.recordingPath()}'`];
        recorder.running = true;
        root.recording = true;
    }

    function toggleRecordRegion() {
        if (root.recording)
            root.stopRecording();
        else
            root.recordRegion();
    }

    function setDark(value) {
        if (root.dark === value)
            return;
        root.dark = value;
        scheme.command = ["gsettings", "set", "org.gnome.desktop.interface",
            "color-scheme", root.dark ? "prefer-dark" : "default"];
        scheme.running = true;
    }

    function toggleDark() {
        root.setDark(!root.dark);
    }

    /*
     * The VPN toggle works with whichever VPN you have: a NetworkManager VPN or
     * WireGuard connection, Cloudflare WARP (warp-cli), Tailscale or Mullvad.
     * On: the first one found is brought up (Config vpn.prefer picks another by
     * name). Off: whichever is up goes down.
     */
    function toggleVpn() {
        if (!root.hasVpn)
            return;
        const up = root.vpnConnections.find(c => c.active);
        const prefer = Config.get("vpn.prefer", "");
        const target = up ?? root.vpnConnections.find(c => c.name === prefer) ?? root.vpnConnections[0];
        const on = !up;
        const commands = {
            nm: ["nmcli", "connection", on ? "up" : "down", "id", target.name],
            warp: ["warp-cli", "--accept-tos", on ? "connect" : "disconnect"],
            tailscale: ["tailscale", on ? "up" : "down"],
            mullvad: ["mullvad", on ? "connect" : "disconnect"]
        };
        vpn.command = commands[target.kind];
        vpn.running = true;
        // Shown as changed at once; the next read confirms it.
        root.vpnConnections = root.vpnConnections.map(c => Object.assign({}, c, { active: c === target ? on : (on ? c.active : false) }));
    }

    function readVpn() {
        vpnList.running = false;
        vpnList.running = true;
    }

    Timer {
        // Connections also change outside the shell (and take a moment to come
        // up), so the state is read again now and then rather than only once.
        interval: 8000
        running: true
        repeat: true
        onTriggered: root.readVpn()
    }

    Process {
        id: rfkill
    }

    Process {
        id: night
    }

    Process {
        id: vpn

        onExited: settleVpn.restart()
    }

    Timer {
        id: settleVpn

        interval: 1500
        onTriggered: root.readVpn()
    }

    Process {
        id: scheme
    }

    Process {
        id: recorder

        // Cancelling the selection, or the recorder dying, must not leave the
        // toggle claiming something is still being recorded.
        onExited: root.recording = false
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
            'PATH="$PATH:$HOME/.cargo/bin:$HOME/.local/bin:/usr/local/bin"; ' +
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

    // Every VPN this machine has, as kind|name|state lines.
    Process {
        id: vpnList

        running: true
        command: ["sh", "-c", `
            nmcli -t -f NAME,TYPE,STATE connection show 2>/dev/null | while IFS=: read -r name type state; do
                case "$type" in *vpn*|*wireguard*) echo "nm|$name|$state" ;; esac
            done
            if command -v warp-cli >/dev/null 2>&1; then
                st=$(warp-cli --accept-tos status 2>/dev/null)
                case "$st" in *Connected*) echo "warp|Cloudflare WARP|activated" ;; *) echo "warp|Cloudflare WARP|off" ;; esac
            fi
            if command -v tailscale >/dev/null 2>&1; then
                tailscale status >/dev/null 2>&1 && echo "tailscale|Tailscale|activated" || echo "tailscale|Tailscale|off"
            fi
            if command -v mullvad >/dev/null 2>&1; then
                case "$(mullvad status 2>/dev/null)" in Connected*) echo "mullvad|Mullvad|activated" ;; *) echo "mullvad|Mullvad|off" ;; esac
            fi`]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const parts = line.split("|");
                    if (parts.length < 3)
                        continue;
                    found.push({ kind: parts[0], name: parts[1], active: parts[2] === "activated" });
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

    /*
     * The shell follows the same setting it hands GTK apps. Toggling dark mode
     * and watching Firefox change while the bar stayed black made the toggle
     * look like it only half worked.
     */
    Binding {
        target: Theme
        property: "dark"
        value: root.dark
    }
}
