pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services
import qs.theme

/*
 * This machine, and this shell.
 */
SettingsPage {
    id: page

    // Read once when the page opens: { host, os, kernel, cpu, gpu, memory, uptime, hyprland, quickshell, stratum }.
    property var facts: ({})

    icon: "info"
    title: "About"
    detail: "This computer and the shell running on it."

    Process {
        running: true
        command: ["sh", "-c", `
            . /etc/os-release 2>/dev/null
            echo "os=\${PRETTY_NAME:-Linux}"
            echo "host=$(cat /proc/sys/kernel/hostname 2>/dev/null)"
            echo "kernel=$(uname -r)"
            echo "cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//; s/([^)]*)//g; s/ CPU//; s/ @.*//; s/  */ /g')"
            echo "cores=$(nproc)"
            echo "gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -n1 | cut -d: -f3- | sed 's/^ *//; s/ (rev.*//')"
            echo "memory=$(awk '/MemTotal/ {printf "%.0f GiB", $2/1048576}' /proc/meminfo)"
            echo "uptime=$(uptime -p 2>/dev/null | sed 's/^up //')"
            echo "hyprland=$(hyprctl version -j 2>/dev/null | grep -m1 '"tag"' | cut -d'"' -f4)"
            echo "quickshell=$(qs --version 2>/dev/null | head -n1 | awk '{print $2}')"
            echo "stratum=$(git -C "$1" log -1 --format='%h · %cs' 2>/dev/null)"
            echo "disk=$(df -h --output=used,size / 2>/dev/null | tail -n1 | awk '{print $1 " of " $2}')"
        `, "sh", Quickshell.shellPath("")]

        stdout: StdioCollector {
            onStreamFinished: {
                const out = {};
                for (const line of text.split("\n")) {
                    const at = line.indexOf("=");
                    if (at > 0)
                        out[line.slice(0, at)] = line.slice(at + 1).trim();
                }
                page.facts = out;
            }
        }
    }

    // The name, in dots, the way it would be printed on the back of the device.
    Rectangle {
        height: 180
        radius: Theme.rTile
        color: Theme.surfaceHi
        border.width: 1
        border.color: Theme.line

        Column {
            anchors.centerIn: parent
            spacing: Theme.space(2)

            DotText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "STRATUM"
                size: 46
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.space(2)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.dot
                    height: Theme.dot
                    radius: width / 2
                    color: Theme.accent
                }

                SectionLabel {
                    text: page.facts.stratum ? `build ${page.facts.stratum}` : "a shell for hyprland"
                    color: Theme.fgDim
                }
            }
        }
    }

    SettingCard {
        title: "this computer"

        Repeater {
            model: [
                ["Name", page.facts.host],
                ["System", page.facts.os],
                ["Processor", page.facts.cpu ? `${page.facts.cpu} · ${page.facts.cores} threads` : ""],
                ["Graphics", page.facts.gpu],
                ["Memory", page.facts.memory],
                ["Storage", page.facts.disk ? `${page.facts.disk} used` : ""],
                ["Up for", page.facts.uptime]
            ].filter(r => (r[1] ?? "").length > 0)

            SettingRow {
                id: fact

                required property var modelData

                title: fact.modelData[0]

                Text {
                    width: Math.min(implicitWidth, 420)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    text: fact.modelData[1]
                    color: Theme.fgBright
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    SettingCard {
        title: "software"

        Repeater {
            model: [
                ["Kernel", page.facts.kernel],
                ["Hyprland", page.facts.hyprland],
                ["Quickshell", page.facts.quickshell],
                ["Displays", Quickshell.screens.map(s => `${s.name} ${s.width}×${s.height}`).join(", ")]
            ].filter(r => (r[1] ?? "").length > 0)

            SettingRow {
                id: soft

                required property var modelData

                title: soft.modelData[0]

                Text {
                    width: Math.min(implicitWidth, 420)
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignRight
                    text: soft.modelData[1]
                    color: Theme.fgBright
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }
            }
        }

        SettingRow {
            title: "Shell folder"
            detail: Quickshell.shellPath("")

            LinkButton {
                text: "open"
                onClicked: Quickshell.execDetached(["xdg-open", Quickshell.shellPath("")])
            }
        }
    }
}
