import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The quick toggles, four to a row, in the order `controlCentre.toggles` says.
 *
 * Each names the service that owns its state rather than holding any itself, so
 * the bar's indicators and these stay in step without either knowing about the
 * other.
 *
 * Hold any of them to arrange: drag a circle to another slot to reorder, tap the
 * x to take one off, tap a name underneath to bring one back. The order is
 * written to shell.json as it changes, and "done" (or closing the panel) ends it.
 */
Item {
    id: root

    readonly property real cell: width / 4
    readonly property real rowHeight: 86
    readonly property real rowGap: Theme.space(3)
    readonly property int columns: 4

    property bool arranging: false

    // While one is being dragged: where it started, and the slot it is over now.
    // The others read these to make room, so they move aside as it passes.
    property int dragFrom: -1
    property int dragTo: -1

    // Every toggle there is. The config chooses which of these show, and where.
    readonly property var registry: ({
        "dnd": { icon: "bell-off", label: "dnd", active: Notifs.dnd, available: true, act: () => Notifs.toggleDnd() },
        "night": { icon: "moon", label: "night", active: Toggles.night, available: Toggles.hasNight, act: () => Toggles.toggleNight() },
        "airplane": { icon: "airplane", label: "airplane", active: Toggles.airplane, available: true, act: () => Toggles.toggleAirplane() },
        "caffeine": { icon: "coffee", label: "caffeine", active: Toggles.caffeine, available: true, act: () => Toggles.toggleCaffeine() },
        "mic": { icon: "mic-off", label: "mic", active: Audio.sourceMuted, available: true, act: () => Audio.toggleSourceMuted() },
        "record": { icon: "record", label: "record", active: Toggles.recording, available: Toggles.hasRecorder, act: () => Toggles.toggleRecording() },
        "recarea": { icon: "scan", label: "rec area", active: Toggles.recording, available: Toggles.hasRecorder, act: () => { Shell.close(); Toggles.toggleRecordRegion(); } },
        "vpn": { icon: "shield", label: "vpn", active: Toggles.vpnUp, available: Toggles.hasVpn, act: () => Toggles.toggleVpn() },
        "theme": { icon: "contrast", label: "dark", active: Toggles.dark, available: true, act: () => Toggles.toggleDark() },

        // Not on the panel until added: hold a toggle, then pick from the names.
        "wifi": { icon: Wifi.enabled ? "wifi" : "wifi-off", label: "wifi", active: Wifi.enabled, available: true, act: () => Wifi.setEnabled(!Wifi.enabled) },
        "bluetooth": { icon: Bt.enabled ? "bluetooth" : "bluetooth-off", label: "bluetooth", active: Bt.enabled, available: Bt.available, act: () => Bt.toggle() },
        "mute": { icon: "volume-mute", label: "mute", active: Audio.muted, available: true, act: () => Audio.toggleMuted() },
        "eco": { icon: "bolt", label: "eco", active: Power.eco, available: Power.hasBattery, act: () => Power.setProfile(Power.eco ? "balanced" : "power-saver") },
        "lock": { icon: "lock", label: "lock", active: false, available: true, act: () => { Shell.close(); Quickshell.execDetached(["loginctl", "lock-session"]); } },
        "shot": { icon: "scan", label: "capture", active: false, available: true, act: () => Screenshot.regionSoon() },
        "widgets": { icon: "app", label: "widgets", active: Widgets.editing, available: true, act: () => { Shell.close(); Widgets.editing = !Widgets.editing; } },
        "settings": { icon: "settings", label: "settings", active: false, available: true, act: () => Shell.toggle("settings", Shell.openScreen, "control") }
    })

    // The order here is the order the add-chips are offered in.
    readonly property var allIds: ["dnd", "night", "airplane", "caffeine", "mic", "record", "vpn", "theme",
        "wifi", "bluetooth", "mute", "eco", "lock", "shot", "recarea", "widgets", "settings"]

    // Unknown names in the file are ignored rather than drawn as holes.
    readonly property var order: (Config.get("controlCentre.toggles", root.allIds) ?? []).filter(id => root.allIds.includes(id))
    readonly property var missing: root.allIds.filter(id => !root.order.includes(id))
    readonly property int rows: Math.max(1, Math.ceil(root.order.length / root.columns))
    readonly property real gridHeight: root.rows * root.rowHeight + (root.rows - 1) * root.rowGap

    height: root.gridHeight + (root.arranging ? footer.height + Theme.space(3) : 0)

    Behavior on height {
        NumberAnimation {
            duration: Theme.standard
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft
        }
    }

    function save(ids) {
        Config.set("controlCentre.toggles", ids);
    }

    function move(from, to) {
        const next = root.order.slice();
        const [id] = next.splice(from, 1);
        next.splice(Math.max(0, Math.min(next.length, to)), 0, id);
        root.save(next);
    }

    function remove(id) {
        root.save(root.order.filter(x => x !== id));
    }

    function add(id) {
        root.save(root.order.concat([id]));
    }

    // Leaving the panel ends arranging, so it is never found half-done.
    Connections {
        target: Shell

        function onOpenPanelChanged() {
            root.arranging = false;
        }
    }

    Repeater {
        model: root.order

        Item {
            id: slotItem

            required property string modelData
            required property int index

            readonly property var entry: root.registry[modelData]

            // Where this one is shown, which differs from where it is in the order
            // only while another is being dragged across it.
            readonly property int shown: {
                const from = root.dragFrom;
                const to = root.dragTo;
                if (from < 0 || index === from)
                    return index;
                if (from < to && index > from && index <= to)
                    return index - 1;
                if (from > to && index >= to && index < from)
                    return index + 1;
                return index;
            }

            // The slot the dragged circle is currently over.
            readonly property int overSlot: {
                const cx = slotItem.x + mover.x + slotItem.width / 2;
                const cy = slotItem.y + mover.y + slotItem.height / 2;
                const col = Math.max(0, Math.min(root.columns - 1, Math.floor(cx / root.cell)));
                const row = Math.max(0, Math.min(root.rows - 1, Math.floor(cy / (root.rowHeight + root.rowGap))));
                return Math.min(root.order.length - 1, row * root.columns + col);
            }

            x: (shown % root.columns) * root.cell
            y: Math.floor(shown / root.columns) * (root.rowHeight + root.rowGap)
            width: root.cell
            height: root.rowHeight

            Behavior on x {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            // The part that is dragged. The slot itself keeps its place by
            // binding, so letting go simply sends this back to zero.
            Item {
                id: mover

                width: parent.width
                height: parent.height
                z: drag.active ? 10 : 0
                scale: drag.active ? 1.08 : 1

                Behavior on x {
                    enabled: !drag.active

                    NumberAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }
                }

                Behavior on y {
                    enabled: !drag.active

                    NumberAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.micro
                    }
                }

                ToggleCircle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    icon: slotItem.entry.icon
                    label: slotItem.entry.label
                    active: slotItem.entry.active
                    available: slotItem.entry.available || root.arranging
                    interactive: !root.arranging
                    onToggled: slotItem.entry.act()
                    onHeld: root.arranging = true
                }

                DragHandler {
                    id: drag

                    enabled: root.arranging
                    xAxis.enabled: true
                    yAxis.enabled: true

                    onActiveChanged: {
                        if (active) {
                            root.dragFrom = slotItem.index;
                            root.dragTo = slotItem.index;
                            return;
                        }
                        const target = slotItem.overSlot;
                        mover.x = 0;
                        mover.y = 0;
                        root.dragFrom = -1;
                        root.dragTo = -1;
                        if (target !== slotItem.index)
                            root.move(slotItem.index, target);
                    }
                }

                Binding {
                    target: root
                    property: "dragTo"
                    value: slotItem.overSlot
                    when: drag.active
                    restoreMode: Binding.RestoreNone
                }

                // Takes it off the panel. It stays in the palette underneath.
                Rectangle {
                    visible: root.arranging
                    x: parent.width / 2 + 14
                    y: 0
                    width: 20
                    height: 20
                    radius: 10
                    color: Theme.accent

                    Glyph {
                        anchors.centerIn: parent
                        name: "close"
                        size: 11
                        stroke: 2.2
                        color: Theme.bg
                    }

                    TapHandler {
                        onTapped: root.remove(slotItem.modelData)
                    }
                }
            }
        }
    }

    Column {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: root.gridHeight + Theme.space(3)
        spacing: Theme.space(2)
        visible: root.arranging
        opacity: root.arranging ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.standard
            }
        }

        Flow {
            width: parent.width
            spacing: Theme.space(2)
            visible: root.missing.length > 0

            Repeater {
                model: root.missing

                Rectangle {
                    id: chip

                    required property string modelData

                    width: chipRow.implicitWidth + Theme.space(4)
                    height: 34
                    radius: height / 2
                    color: chipHover.hovered ? Theme.surfaceTop : Theme.surfaceHi

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: Theme.space(2)

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            name: root.registry[chip.modelData].icon
                            size: 15
                            color: Theme.fg
                        }

                        SectionLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.registry[chip.modelData].label
                            color: Theme.fg
                        }

                        SectionLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+"
                            color: Theme.fgBright
                        }
                    }

                    HoverHandler {
                        id: chipHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.add(chip.modelData)
                    }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: doneLabel.implicitWidth + Theme.space(5)
            height: 32
            radius: height / 2
            color: Theme.fg

            SectionLabel {
                id: doneLabel

                anchors.centerIn: parent
                text: "done"
                color: Theme.bg
            }

            TapHandler {
                onTapped: root.arranging = false
            }
        }
    }
}
