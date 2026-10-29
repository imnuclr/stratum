import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme
import qs.utils

/*
 * The status stack at the foot of the bar.
 *
 * Items that own a popout carry it; the rest are readings. Each hands its own
 * centre to Popouts so the panel opens level with the thing that triggered it,
 * which on a vertical bar is a y rather than an x.
 */
Column {
    id: root

    required property string monitorName

    spacing: Theme.space(3)

    SectionLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Keyboard.code
        visible: Keyboard.code.length > 0
    }

    Repeater {
        model: [
            { kind: "network", popout: "network" },
            { kind: "bluetooth", popout: "bluetooth" },
            { kind: "audio", popout: "audio" },
            { kind: "dnd", popout: "" },
            { kind: "profile", popout: "" },
            { kind: "battery", popout: "" },
            { kind: "power", popout: "" }
        ]

        Item {
            id: item

            required property var modelData

            readonly property bool hovered: hover.hovered
            readonly property bool lit: hovered || (modelData.popout.length > 0 && Popouts.current === modelData.popout && Popouts.open)

            anchors.horizontalCenter: parent.horizontalCenter
            width: 24
            height: Math.max(20, content.implicitHeight)

            Column {
                id: content

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 1

                // Wi-Fi gets its own component because the glyph is built from
                // arcs that light by signal strength, not a single path.
                WifiGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: item.modelData.kind === "network" && !Network.wiredActive && Wifi.enabled
                    size: 17
                    strength: Network.strength
                    color: item.lit ? Theme.fg : Theme.fgBright
                }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: item.modelData.kind === "network" && Network.wiredActive
                    name: "ethernet"
                    size: 17
                    color: item.lit ? Theme.fg : Theme.fgBright
                }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: item.modelData.kind === "bluetooth"
                    name: Bt.enabled ? "bluetooth" : "bluetooth-off"
                    size: 17
                    color: item.lit ? Theme.fg : Theme.fgBright
                }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: item.modelData.kind === "audio"
                    name: Icons.volume(Audio.volume, Audio.muted)
                    size: 17
                    color: item.lit ? Theme.fg : Theme.fgBright
                }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: item.modelData.kind === "dnd"
                    name: Notifs.dnd ? "bell-off" : "bell"
                    size: 17
                    color: Notifs.dnd ? Theme.accent : (item.lit ? Theme.fg : Theme.fgBright)
                }

                /*
                 * A reading, not a control: the profile is set in the control
                 * centre, where the four levels are named and the consequence of
                 * each is legible. A click target that silently cycles through
                 * them is how you end up on power-saver without knowing.
                 */
                ProfileGlyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: item.modelData.kind === "profile"
                    size: 17
                    level: Math.max(1, Math.round((Power.profiles.indexOf(Power.profile) + 1)
                        / Math.max(1, Power.profiles.length) * 4))
                    color: Theme.fgBright
                }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: item.modelData.kind === "battery" && Power.hasBattery
                    name: Power.charging ? "battery-charging" : "battery-vertical"
                    size: 17
                    color: Power.critical ? Theme.accent : (item.lit ? Theme.fg : Theme.fgDim)
                }

                DotText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: item.modelData.kind === "battery" && Power.hasBattery
                    text: `${Math.round(Power.percentage * 100)}`
                    size: 13
                    color: Power.critical ? Theme.accent : Theme.fgBright
                }

                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: item.modelData.kind === "power"
                    name: "power"
                    size: 17
                    color: item.lit ? Theme.accent : Theme.fgDim
                }
            }

            HoverHandler {
                id: hover

                onHoveredChanged: {
                    if (item.modelData.popout.length === 0)
                        return;
                    if (hovered) {
                        const centre = item.mapToItem(null, 0, item.height / 2);
                        Popouts.showAtY(item.modelData.popout, centre.y, root.monitorName);
                    } else {
                        Popouts.release(item.modelData.popout);
                    }
                }
            }

            TapHandler {
                onTapped: {
                    if (item.modelData.kind === "dnd")
                        Notifs.toggleDnd();
                    else if (item.modelData.kind === "power")
                        Shell.toggle("session");
                }
            }
        }
    }
}
