pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The connection you are on and the ones you could be on.
 */
SettingsPage {
    id: page

    icon: "wifi"
    title: "Network"
    detail: "Wi-Fi, wired connections, VPN and airplane mode."

    Component.onCompleted: Wifi.setScanning(true)
    Component.onDestruction: Wifi.setScanning(false)

    SettingCard {
        title: "status"

        SettingRow {
            title: Network.connected ? Network.label : "Not connected"
            detail: !Network.connected ? "No network is up."
                : [Network.wiredActive ? "wired" : `wi-fi · ${Network.strength}% signal`,
                    Network.online ? "online" : (Network.portal ? "needs a sign-in page" : "no internet"),
                    Network.ipv4].filter(s => s.length > 0).join(" · ")

            Glyph {
                name: Network.wiredActive ? "ethernet" : (Network.connected ? "wifi" : "wifi-off")
                size: 22
                color: Network.online ? Theme.fg : Theme.fgDim
            }
        }

        SettingRow {
            title: "Airplane mode"
            detail: "Turns off every radio: Wi-Fi and Bluetooth."

            Switch {
                checked: Toggles.airplane
                onToggled: Toggles.toggleAirplane()
            }
        }

        SettingRow {
            visible: Toggles.hasVpn
            title: "VPN"
            detail: Toggles.vpnConnections.map(c => c.name).join(", ")

            Switch {
                checked: Toggles.vpnUp
                onToggled: Toggles.toggleVpn()
            }
        }
    }

    SettingCard {
        title: "wi-fi"
        visible: Wifi.available

        SettingRow {
            title: "Wi-Fi"

            Switch {
                checked: Wifi.enabled
                onToggled: value => Wifi.setEnabled(value)
            }
        }

        // Asked for in place, under the network that needs it.
        Item {
            width: parent.width
            height: visible ? 60 : 0
            visible: Wifi.pendingNetwork !== null

            TextField {
                id: psk

                anchors.left: parent.left
                anchors.right: join.left
                anchors.rightMargin: Theme.space(2)
                anchors.verticalCenter: parent.verticalCenter
                height: 34
                echoMode: TextInput.Password
                placeholder: `password for ${Wifi.pendingNetwork?.name ?? ""}`
                onAccepted: text => {
                    Wifi.submitPassword(text);
                    psk.text = "";
                }
                onVisibleChanged: if (visible) psk.take()
            }

            LinkButton {
                id: join

                anchors.right: cancel.left
                anchors.rightMargin: Theme.space(1)
                anchors.verticalCenter: parent.verticalCenter
                text: "join"
                onClicked: {
                    Wifi.submitPassword(psk.text);
                    psk.text = "";
                }
            }

            LinkButton {
                id: cancel

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "cancel"
                onClicked: Wifi.cancelPassword()
            }
        }

        Repeater {
            model: Wifi.enabled ? Wifi.networks.slice(0, 14) : []

            ChoiceRow {
                required property var modelData

                strength: Math.round(modelData.signalStrength * 100)
                title: modelData.name
                sub: [modelData.connected ? "connected" : (modelData.known ? "saved" : ""),
                    Wifi.isSecure(modelData) ? "secured" : "open",
                    `${Math.round(modelData.signalStrength * 100)}%`].filter(s => s.length > 0).join(" · ")
                chosen: modelData.connected
                trailing: modelData.connected ? "disconnect" : ""
                onTrailingClicked: Wifi.disconnect()
                onClicked: {
                    if (modelData.connected)
                        return;
                    if (Wifi.needsPassword(modelData))
                        Wifi.requestPassword(modelData);
                    else
                        Wifi.connect(modelData);
                }
            }
        }
    }

    SettingCard {
        title: "wired"
        visible: Network.wiredDevices.length > 0

        Repeater {
            model: Network.wiredDevices

            SettingRow {
                id: wire

                required property var modelData

                title: wire.modelData.name
                detail: wire.modelData.connected ? "connected" : "unplugged or off"

                Switch {
                    checked: wire.modelData.connected
                    onToggled: value => Network.setWiredConnected(wire.modelData, value)
                }
            }
        }
    }

    SettingCard {
        visible: Wifi.settingsApp.length > 0

        SettingRow {
            title: "Saved networks, static addresses and more"
            detail: `In ${Wifi.settingsApp}.`

            LinkButton {
                text: "open"
                onClicked: Wifi.openSettings()
            }
        }
    }
}
