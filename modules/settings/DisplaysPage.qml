pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Every screen in one place: where they sit beside each other, how each one
 * runs, how bright it is, and what the shell puts on it.
 *
 * Drag a screen in the arrangement to move it; it snaps to the edges of the
 * others. Pick one to change its resolution, refresh rate and scale. Every
 * change is tried at once and undoes itself unless kept, in case the screen
 * cannot show what was asked for.
 */
SettingsPage {
    id: page

    property string selected: ""
    readonly property var monitor: Monitors.byName(page.selected) ?? Monitors.list[0] ?? null
    readonly property string name: page.monitor?.name ?? ""
    readonly property var modes: Monitors.modesOf(page.monitor)
    readonly property int modeIndex: Math.max(0, page.modes.findIndex(m => m.w === page.monitor?.width && m.h === page.monitor?.height))
    readonly property var rates: page.modes[page.modeIndex]?.rates ?? []
    readonly property var scales: [1, 1.25, 1.333333, 1.5, 1.6, 1.666667, 1.75, 2, 2.5, 3]
    readonly property bool vertical: Config.forMonitor(page.name, "bar.orientation", "vertical") === "vertical"
    readonly property string prefix: `monitors.${page.name}.bar`

    icon: "monitor"
    title: "Displays"
    detail: "Arrangement, resolution, refresh rate, scale and brightness for each screen."

    Component.onCompleted: Monitors.refresh()

    function label(m) {
        return [m?.make, m?.model].filter(s => s && s.length > 0 && s !== "Unknown").join(" ") || m?.name || "";
    }

    // Kept or undone: shown while a change is being tried.
    Rectangle {
        visible: Monitors.trying
        height: visible ? 64 : 0
        radius: Theme.rTile
        color: Theme.fg

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space(5)
            anchors.verticalCenter: parent.verticalCenter
            text: `Keep these display settings? Going back in ${Monitors.countdown}s.`
            color: Theme.bg
            font.family: Theme.fontUi
            font.pixelSize: 14
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.space(3)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(2)

            LinkButton {
                text: "go back"
                onClicked: Monitors.revert()
            }

            LinkButton {
                text: "keep"
                onClicked: Monitors.keep()
            }
        }
    }

    // The screens as rectangles, at their real proportions and positions.
    Rectangle {
        id: arrangement

        readonly property real pad: 32
        readonly property var boxes: Monitors.list.map(m => ({
            name: m.name, x: m.x, y: m.y,
            w: m.width / Math.max(0.1, m.scale), h: m.height / Math.max(0.1, m.scale), m: m
        }))
        readonly property real minX: Math.min(...arrangement.boxes.map(b => b.x), 0)
        readonly property real minY: Math.min(...arrangement.boxes.map(b => b.y), 0)
        readonly property real spanW: Math.max(1, Math.max(...arrangement.boxes.map(b => b.x + b.w), 1) - arrangement.minX)
        readonly property real spanH: Math.max(1, Math.max(...arrangement.boxes.map(b => b.y + b.h), 1) - arrangement.minY)
        readonly property real k: Math.min((width - pad * 2) / spanW, (height - pad * 2) / spanH)
        readonly property real offX: (width - spanW * k) / 2
        readonly property real offY: (height - spanH * k) / 2

        height: 260
        radius: Theme.rTile
        color: Theme.surfaceHi
        border.width: 1
        border.color: Theme.line

        // Dots behind, as on a cutting mat.
        DotField {
            anchors.centerIn: parent
            rows: Math.floor((parent.height - 24) / (Theme.dotPitch * 2))
            cell: Theme.dotPitch * 2
            dotSize: 2
            offColor: Theme.line
            values: Array.from({ length: Math.max(0, Math.floor((parent.width - 24) / (Theme.dotPitch * 2))) }, () => 0)
        }

        /*
         * Where a dragged screen lands: beside the nearest edge of another one,
         * lined up with it when close. Positions are in Hyprland's layout
         * coordinates, which are logical pixels.
         */
        function snap(box, x, y) {
            const near = 80;
            let bx = x, by = y;
            let best = Infinity;
            for (const o of arrangement.boxes) {
                if (o.name === box.name)
                    continue;
                const candidates = [
                    [o.x + o.w, y], [o.x - box.w, y],
                    [x, o.y + o.h], [x, o.y - box.h]
                ];
                for (const [cx, cy] of candidates) {
                    const d = Math.hypot(cx - x, cy - y);
                    if (d < best) {
                        best = d;
                        bx = cx;
                        by = cy;
                    }
                }
            }
            // Edges that nearly line up are lined up.
            for (const o of arrangement.boxes) {
                if (o.name === box.name)
                    continue;
                for (const ty of [o.y, o.y + o.h - box.h, o.y + (o.h - box.h) / 2])
                    if (Math.abs(by - ty) < near)
                        by = ty;
                for (const tx of [o.x, o.x + o.w - box.w, o.x + (o.w - box.w) / 2])
                    if (Math.abs(bx - tx) < near)
                        bx = tx;
            }
            return [Math.round(bx), Math.round(by)];
        }

        Repeater {
            model: arrangement.boxes

            Rectangle {
                id: tile

                required property var modelData

                readonly property bool chosen: tile.modelData.name === page.name
                readonly property real homeX: arrangement.offX + (tile.modelData.x - arrangement.minX) * arrangement.k
                readonly property real homeY: arrangement.offY + (tile.modelData.y - arrangement.minY) * arrangement.k

                x: homeX
                y: homeY
                width: tile.modelData.w * arrangement.k - 4
                height: tile.modelData.h * arrangement.k - 4
                radius: 10
                color: tile.chosen ? Theme.fg : Theme.surfaceTop
                border.width: 1
                border.color: tile.chosen ? Theme.fg : Theme.lineHi
                z: drag.active ? 2 : 1

                Behavior on x {
                    enabled: !drag.active

                    NumberAnimation {
                        duration: Theme.sheetMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Behavior on y {
                    enabled: !drag.active

                    NumberAnimation {
                        duration: Theme.sheetMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tile.modelData.name
                        color: tile.chosen ? Theme.bg : Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${tile.modelData.m.width} × ${tile.modelData.m.height}`
                        color: tile.chosen ? Theme.bg : Theme.fgDim
                        opacity: 0.8
                        font.family: Theme.fontUi
                        font.pixelSize: 11
                        renderType: Text.NativeRendering
                    }
                }

                HoverHandler {
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                }

                TapHandler {
                    onTapped: page.selected = tile.modelData.name
                }

                DragHandler {
                    id: drag

                    // One screen alone has nothing to sit beside.
                    enabled: arrangement.boxes.length > 1

                    onActiveChanged: {
                        if (active) {
                            page.selected = tile.modelData.name;
                            return;
                        }
                        const lx = (tile.x - arrangement.offX) / arrangement.k + arrangement.minX;
                        const ly = (tile.y - arrangement.offY) / arrangement.k + arrangement.minY;
                        const [sx, sy] = arrangement.snap(tile.modelData, lx, ly);
                        // Back to its bindings; the new position arrives from Hyprland.
                        tile.x = Qt.binding(() => tile.homeX);
                        tile.y = Qt.binding(() => tile.homeY);
                        if (sx !== tile.modelData.x || sy !== tile.modelData.y)
                            Monitors.attempt({ [tile.modelData.name]: { x: sx, y: sy } });
                    }
                }
            }
        }

        SectionLabel {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: Theme.space(3)
            visible: arrangement.boxes.length > 1
            text: "drag to arrange · click to choose"
            dim: true
        }
    }

    SettingCard {
        title: page.monitor ? `${page.name} · ${page.label(page.monitor)}` : "no screen found"
        visible: !!page.monitor

        SettingRow {
            title: "Resolution"

            Dropdown {
                menuWidth: 200
                model: page.modes.map(m => `${m.w} × ${m.h}`)
                current: page.modeIndex
                onPicked: index => {
                    const m = page.modes[index];
                    Monitors.attempt({ [page.name]: { width: m.w, height: m.h, hz: m.rates[0] } });
                }
            }
        }

        SettingRow {
            title: "Refresh rate"
            detail: Power.eco && page.name.startsWith("eDP") && Config.get("power.ecoRefresh", true)
                ? "Eco lowers this while it is on." : ""

            Dropdown {
                menuWidth: 200
                model: page.rates.map(r => `${Math.round(r * 100) / 100} Hz`)
                current: Math.max(0, page.rates.findIndex(r => Math.abs(r - (page.monitor?.refreshRate ?? 0)) < 0.5))
                onPicked: index => Monitors.attempt({ [page.name]: { hz: page.rates[index] } })
            }
        }

        SettingRow {
            title: "Scale"
            detail: page.monitor
                ? `Looks like ${Math.round(page.monitor.width / page.monitor.scale)} × ${Math.round(page.monitor.height / page.monitor.scale)}. Bigger makes everything larger.`
                : ""

            Dropdown {
                menuWidth: 200
                model: page.scales.map(s => `${Math.round(s * 100)}%`)
                current: {
                    const now = page.monitor?.scale ?? 1;
                    let best = 0;
                    for (let i = 0; i < page.scales.length; i++)
                        if (Math.abs(page.scales[i] - now) < Math.abs(page.scales[best] - now))
                            best = i;
                    return best;
                }
                onPicked: index => Monitors.attempt({ [page.name]: { scale: page.scales[index] } })
            }
        }

        SettingRow {
            id: lightRow

            readonly property var shade: Brightness.forMonitor(page.name)

            visible: !!shade
            title: "Brightness"
            detail: shade ? `${Math.round(shade.value * 100)}%` : ""

            LevelSlider {
                width: 200
                count: 20
                value: lightRow.shade?.value ?? 0
                onMoved: v => Brightness.setForMonitor(page.name, v)
            }
        }

        SettingRow {
            visible: !!(Config.get("displays", {}) ?? {})[page.name]
            title: "Kept by Stratum"
            detail: "These settings are put back at startup and after Hyprland reloads. Forget them to use your Hyprland config again."

            LinkButton {
                text: "forget"
                danger: true
                onClicked: Monitors.forget(page.name)
            }
        }
    }

    SettingCard {
        title: "on this screen"
        visible: !!page.monitor

        SettingRow {
            title: "Bar"

            Switch {
                checked: Config.forMonitor(page.name, "bar.enabled", true)
                onToggled: value => Config.set(`${page.prefix}.enabled`, value)
            }
        }

        SettingRow {
            title: "Bar edge"
            detail: "Default follows the Bar page."

            Segmented {
                readonly property var edges: page.vertical ? ["default", "left", "right"] : ["default", "top", "bottom"]
                readonly property string set: Config.get(`${page.prefix}.edge`, "")

                model: edges
                current: Math.max(0, edges.indexOf(set))
                onPicked: index => {
                    if (index === 0)
                        Config.unset(`${page.prefix}.edge`);
                    else
                        Config.set(`${page.prefix}.edge`, edges[index]);
                }
            }
        }

        SettingRow {
            title: "Wallpaper"
            detail: Wallpaper.forMonitor(page.name).split("/").pop()

            LinkButton {
                text: "choose"
                onClicked: Shell.open("picker", page.name)
            }
        }

        SettingRow {
            title: "Widgets"
            detail: "Each screen keeps its own arrangement."

            LinkButton {
                text: "reset layout"
                onClicked: Widgets.reset(page.name)
            }
        }
    }

    SettingCard {
        title: "colour"

        SettingRow {
            title: "Night light"
            detail: Toggles.hasNight ? "Warmer colours, easier on the eyes after dark." : "Needs hyprsunset or wlsunset installed."

            Switch {
                enabled: Toggles.hasNight
                checked: Toggles.night
                onToggled: Toggles.toggleNight()
            }
        }

        SettingRow {
            title: "Dark mode"

            Switch {
                checked: Theme.dark
                onToggled: value => Toggles.setDark(value)
            }
        }
    }
}
