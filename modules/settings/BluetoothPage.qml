pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import qs.components
import qs.services
import qs.theme

/*
 * Headphones, keyboards, phones: the ones you have paired and the ones nearby.
 */
SettingsPage {
    id: page

    icon: "bluetooth"
    title: "Bluetooth"
    detail: Bt.available ? "Pair, connect and forget devices." : "No Bluetooth adapter was found."

    Component.onDestruction: Bt.setDiscovering(false)

    SettingCard {
        visible: Bt.available

        SettingRow {
            title: "Bluetooth"
            detail: Bt.enabled ? Bt.label : "off"

            Switch {
                checked: Bt.enabled
                onToggled: value => Bt.setEnabled(value)
            }
        }

        SettingRow {
            visible: Bt.enabled
            title: "Look for new devices"
            detail: Bt.discovering ? "Searching… put the device in pairing mode." : "Shows devices nearby that are not paired yet."

            Switch {
                checked: Bt.discovering
                onToggled: value => Bt.setDiscovering(value)
            }
        }
    }

    SettingCard {
        title: "devices"
        visible: Bt.enabled
        footnote: Bt.sorted.length === 0 ? "Nothing yet. Turn on searching above to find devices." : "Click a device to connect or disconnect it."

        Repeater {
            model: Bt.sorted

            ChoiceRow {
                required property var modelData

                icon: /audio|head/i.test(modelData.icon ?? "") ? "headphones" : "bluetooth"
                title: modelData.name || modelData.address
                sub: [modelData.connected ? "connected" : (modelData.paired ? "paired" : "nearby"),
                    modelData.batteryAvailable ? `${Math.round(modelData.battery * 100)}% battery` : ""].filter(s => s.length > 0).join(" · ")
                chosen: modelData.connected
                busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
                trailing: modelData.paired ? "forget" : ""
                onTrailingClicked: Bt.forget(modelData)
                onClicked: Bt.toggleDevice(modelData)
            }
        }
    }

    SettingCard {
        visible: Bt.settingsApp.length > 0

        SettingRow {
            title: "More Bluetooth settings"
            detail: `In ${Bt.settingsApp}.`

            LinkButton {
                text: "open"
                onClicked: Bt.openSettings()
            }
        }
    }
}
