pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Every VPN on this machine in one list — WireGuard and OpenVPN connections in
 * NetworkManager, Cloudflare WARP, Tailscale, Mullvad — each with its switch,
 * and the ways to add one: a config file you were given, or signing in to a
 * service you have installed.
 */
SettingsPage {
    id: page

    icon: "shield"
    title: "VPN"
    detail: "Connect, add and remove VPNs. The control centre's VPN toggle uses the one picked here."

    readonly property var list: Toggles.vpnConnections
    readonly property string prefer: Config.get("vpn.prefer", "")

    Component.onCompleted: Toggles.readVpn()

    function kindName(c) {
        return ({ nm: c.detail || "VPN", warp: "Cloudflare WARP", tailscale: "Tailscale", mullvad: "Mullvad" })[c.kind] ?? c.kind;
    }

    // What the last action said, when it said something.
    Rectangle {
        visible: Toggles.vpnMessage.length > 0
        height: visible ? 44 : 0
        radius: Theme.rInner
        color: Theme.surfaceHi
        border.width: 1
        border.color: Theme.line

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space(4)
            anchors.right: dismissMsg.left
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: Toggles.vpnMessage
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }

        Glyph {
            id: dismissMsg

            anchors.right: parent.right
            anchors.rightMargin: Theme.space(3)
            anchors.verticalCenter: parent.verticalCenter
            name: "close"
            size: 13
            color: Theme.fgDim

            TapHandler {
                onTapped: Toggles.vpnMessage = ""
            }
        }
    }

    SettingCard {
        title: "your vpns"
        footnote: page.list.length === 0
            ? "None yet. Add one below."
            : "The ring marks the one the control centre's toggle switches; click a name to change it. Signing out of a service leaves it installed — sign in again to bring it back."

        Repeater {
            model: page.list

            SettingRow {
                id: vpn

                required property var modelData

                readonly property bool preferred: page.prefer.length > 0
                    ? page.prefer === vpn.modelData.name
                    : vpn.modelData === page.list[0]

                title: vpn.modelData.name
                detail: [page.kindName(vpn.modelData),
                    vpn.modelData.active ? "connected" : (vpn.modelData.busy ? "connecting…" : "not connected"),
                    vpn.modelData.kind === "nm" ? "" : vpn.modelData.detail]
                    .filter(t => t.length > 0).join(" · ")

                Row {
                    spacing: Theme.space(2)

                    // Signed in, or not yet: whichever it is, the one action.
                    LinkButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Toggles.canAddVpn(vpn.modelData)
                        text: Toggles.addVpnWord(vpn.modelData)
                        onClicked: Toggles.addVpn(vpn.modelData)
                    }

                    LinkButton {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Toggles.canRemoveVpn(vpn.modelData)
                        text: Toggles.removeVpnWord(vpn.modelData)
                        danger: true
                        onClicked: Toggles.removeVpn(vpn.modelData)
                    }

                    // Which one the control centre's toggle switches.
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 9
                        color: "transparent"
                        border.width: 1
                        border.color: vpn.preferred ? Theme.fg : Theme.lineHi

                        Rectangle {
                            anchors.centerIn: parent
                            width: vpn.preferred ? 9 : 0
                            height: width
                            radius: width / 2
                            color: Theme.fg

                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.standard
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.smooth
                                }
                            }
                        }

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: Config.set("vpn.prefer", vpn.modelData.name)
                        }
                    }

                    Switch {
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: !Toggles.canAddVpn(vpn.modelData)
                        checked: vpn.modelData.active || vpn.modelData.busy
                        onToggled: value => Toggles.setVpn(vpn.modelData, value)
                    }
                }
            }
        }
    }

    SettingCard {
        title: "connect on its own"
        visible: page.list.some(c => c.kind === "nm")

        Repeater {
            model: page.list.filter(c => c.kind === "nm")

            SettingRow {
                id: auto

                required property var modelData

                title: auto.modelData.name
                detail: "Comes up by itself whenever you are online."

                Switch {
                    checked: auto.modelData.autoconnect
                    onToggled: value => Toggles.setVpnAutoconnect(auto.modelData, value)
                }
            }
        }
    }

    SettingCard {
        title: "add a vpn"

        SettingRow {
            title: "From a config file"
            detail: Toggles.canOpenVpn
                ? "A WireGuard .conf or OpenVPN .ovpn file from your VPN provider or your router."
                : "A WireGuard .conf file from your VPN provider or your router. For .ovpn files, install networkmanager-openvpn."

            LinkButton {
                icon: "file"
                text: "choose file"
                onClicked: Picker.file("A WireGuard (.conf) or OpenVPN (.ovpn) file", false, path => Toggles.importVpn(path))
            }
        }

        SettingRow {
            visible: !page.list.some(c => c.kind === "warp")
            title: "Cloudflare WARP"
            detail: "Free. Install it with: paru -S cloudflare-warp-bin, then sudo systemctl enable --now warp-svc. It appears here after."
        }

        SettingRow {
            visible: !page.list.some(c => c.kind === "tailscale")
            title: "Tailscale"
            detail: "Your own devices, privately. Install with: sudo pacman -S tailscale, then sudo systemctl enable --now tailscaled."
        }

        SettingRow {
            visible: !page.list.some(c => c.kind === "mullvad")
            title: "Mullvad"
            detail: "Install the Mullvad app (paru -S mullvad-vpn-bin) and sign in once; it appears here after."
        }
    }
}
