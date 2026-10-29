import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Wireless: enable, the networks in range, and connect/disconnect per network.
 *
 * The scanner runs only while this is on screen. Leaving it on permanently keeps
 * the radio busy for a list nobody is looking at.
 *
 * Deliberately does not import Quickshell.Networking: that module exports a type
 * called Network, which shadows the service singleton of the same name within
 * this file and makes every read silently undefined. Model entries are typed var
 * for the same reason.
 */
Item {
    id: root

    implicitWidth: 268
    implicitHeight: body.implicitHeight

    // Tied to whether this popout is the visible one, not to the component's
    // lifetime: the shared frame keeps the last content loaded through its close
    // transition, so onDestruction never runs and the scanner would stay on for
    // the rest of the session.
    readonly property bool active: Popouts.current === "network"

    onActiveChanged: Wifi.setScanning(active)
    Component.onCompleted: Wifi.setScanning(active)
    Component.onDestruction: Wifi.setScanning(false)

    Column {
        id: body

        width: parent.width
        spacing: Theme.space(2)

        Text {
            text: "Wireless"
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 15
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Row {
            width: body.width

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: body.width - 34
                text: "Enabled"
                dim: false
            }

            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Wifi.enabled
                enabled: Wifi.available
                onToggled: value => Wifi.setEnabled(value)
            }
        }

        SectionLabel {
            dim: true
            text: {
                if (!Wifi.enabled)
                    return "Wi-Fi is off";
                const n = Wifi.count;
                return n === 1 ? "1 network available" : `${n} networks available`;
            }
        }

        Repeater {
            model: Wifi.enabled ? Wifi.networks : []

            Row {
                id: entry

                required property var modelData

                readonly property bool busy: modelData.stateChanging

                width: body.width
                spacing: Theme.space(2)

                WifiGlyph {
                    anchors.verticalCenter: parent.verticalCenter
                    strength: Math.round(entry.modelData.signalStrength * 100)
                    size: 15
                    color: entry.modelData.connected ? Theme.fg : Theme.fgDim
                }

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "lock"
                    size: 11
                    color: Theme.fgFaint
                    visible: Wifi.isSecure(entry.modelData)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: body.width - 72 - (Wifi.isSecure(entry.modelData) ? 11 + Theme.space(2) : 0)
                    elide: Text.ElideRight
                    text: entry.modelData.name
                    color: entry.modelData.connected ? Theme.fg : Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: entry.modelData.connected ? Font.Medium : Font.Normal
                    renderType: Text.NativeRendering
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    icon: entry.modelData.connected ? "link-off" : "link"
                    active: entry.modelData.connected
                    enabled: !entry.busy
                    onClicked: {
                        if (Wifi.needsPassword(entry.modelData))
                            Wifi.requestPassword(entry.modelData);
                        else
                            Wifi.toggleNetwork(entry.modelData);
                    }
                }
            }
        }

        // Passphrase prompt, shown in place of the rescan button while a secured
        // unknown network is waiting on one.
        Column {
            width: body.width
            spacing: Theme.space(2)
            visible: !!Wifi.pendingNetwork

            onVisibleChanged: {
                Popouts.hold = visible;
                if (visible)
                    field.take();
                else
                    field.text = "";
            }

            SectionLabel {
                dim: true
                width: body.width
                elide: Text.ElideRight
                text: `Password for ${Wifi.pendingNetwork?.name ?? ""}`
            }

            TextField {
                id: field

                width: body.width
                echoMode: TextInput.Password
                placeholder: "Passphrase"
                onAccepted: text => Wifi.submitPassword(text)
            }

            Row {
                width: body.width
                spacing: Theme.space(2)

                ActionButton {
                    width: (body.width - Theme.space(2)) / 2
                    icon: "chevron-left"
                    text: "Cancel"
                    onClicked: Wifi.cancelPassword()
                }

                ActionButton {
                    width: (body.width - Theme.space(2)) / 2
                    icon: "check"
                    text: "Connect"
                    enabled: field.text.length >= 8
                    onClicked: Wifi.submitPassword(field.text)
                }
            }
        }

        // Wired devices, shown only when the machine has one. Caelestia keeps
        // ethernet behind a separate view; folding it in keeps the popout a
        // single page, and a machine with no wired port never sees the section.
        Rectangle {
            width: body.width
            height: 1
            color: Theme.line
            visible: Network.wiredDevices.length > 0 && !Wifi.pendingNetwork
        }

        SectionLabel {
            text: "Wired"
            visible: Network.wiredDevices.length > 0 && !Wifi.pendingNetwork
        }

        Repeater {
            model: Wifi.pendingNetwork ? [] : Network.wiredDevices

            Row {
                id: wired

                required property var modelData

                readonly property bool up: wired.modelData.connected

                width: body.width
                spacing: Theme.space(2)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "ethernet"
                    size: 15
                    color: wired.up ? Theme.fg : Theme.fgFaint
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: body.width - 113
                    elide: Text.ElideRight
                    text: wired.modelData.name
                    color: wired.up ? Theme.fg : Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    font.weight: wired.up ? Font.Medium : Font.Normal
                    renderType: Text.NativeRendering
                }

                SectionLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 52
                    horizontalAlignment: Text.AlignRight
                    dim: true
                    text: wired.modelData.linkSpeed > 0 ? `${wired.modelData.linkSpeed}` : "no link"
                }

                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    size: 22
                    icon: wired.up ? "link-off" : "link"
                    active: wired.up
                    onClicked: Network.setWiredConnected(wired.modelData, !wired.up)
                }
            }
        }

        ActionButton {
            width: body.width
            icon: "scan"
            text: "Rescan networks"
            visible: !Wifi.pendingNetwork
            enabled: Wifi.enabled
            busy: Wifi.rescanning
            onClicked: Wifi.rescan()
        }
    }
}
