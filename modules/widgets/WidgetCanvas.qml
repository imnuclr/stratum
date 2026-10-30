pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The desktop's widgets, on the layer just above the wallpaper.
 *
 * Out of edit mode the surface takes the pointer only over the widgets
 * themselves, so their controls work and the rest of the desktop behaves as it
 * always did. Holding on any widget, right-clicking the desktop, Super+Shift+W or
 * the control centre all enter edit mode: a grid shows, and each widget gets an
 * outline, a corner to resize by, a button to remove it and one for its options.
 * Dragging moves a widget, snapping to the grid where it is let go. A gallery
 * down the right shows every widget there is, to add.
 *
 * While windows cover the desktop the widgets are not seen, so they stop asking
 * their services for readings (`live`), and pick up again when it is uncovered.
 *
 * Layout is in grid cells and kept per monitor (services/Widgets.qml).
 */
PanelWindow {
    id: win

    required property ShellScreen monitor

    readonly property bool editing: Widgets.editing
    readonly property bool focused: Hypr.focusedWorkspace?.monitor?.name === win.monitor.name
    readonly property real cell: Widgets.cell

    // Any window on this monitor's workspace counts as covering the desktop.
    readonly property var workspace: Hyprland.monitorFor(win.monitor)?.activeWorkspace ?? null
    readonly property bool covered: (win.workspace?.toplevels?.values?.length ?? 0) > 0
    readonly property bool live: win.editing || !win.covered
    /*
     * Widgets belong to the bare desktop. With a window on the workspace they
     * fade back out of the way — through a translucent terminal, or in the gaps
     * between windows, they were still there behind everything — and return
     * when the desktop is clear. Edit mode always shows them.
     */
    readonly property bool shown: win.editing || !win.covered

    // Clear of the bar, with a margin.
    readonly property bool barSide: Config.get("bar.orientation", "vertical") === "vertical"
    readonly property real fieldLeft: win.barSide
        ? Config.get("bar.width", 56) + Config.get("bar.margin", 10) * 2 + 16 : 24
    readonly property real fieldTop: win.barSide
        ? 24 : Config.get("bar.height", 38) + Config.get("bar.margin", 10) * 2 + 16
    readonly property int cols: Math.max(10, Math.floor((win.monitor.width - win.fieldLeft - 24) / win.cell))
    readonly property int rows: Math.max(10, Math.floor((win.monitor.height - win.fieldTop - 24) / win.cell))

    readonly property var items: Widgets.layoutFor(win.monitor.name, win.cols)

    // Which widget's options are open, by id.
    property string optionsFor: ""
    onEditingChanged: if (!editing) win.optionsFor = ""

    function componentFor(type) {
        return ({
            "clock": clockWidget,
            "greeting": greetingWidget,
            "weather": weatherWidget,
            "date": dateWidget,
            "gpu": gpuWidget,
            "media": mediaWidget,
            "stats": statsWidget,
            "cpu": cpuWidget,
            "memory": memoryWidget,
            "battery": batteryWidget,
            "disk": diskWidget,
            "network": networkWidget,
            "photo": photoWidget
        })[type];
    }

    screen: monitor
    visible: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "stratum-widgets"
    WlrLayershell.keyboardFocus: win.editing && win.focused ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    /*
     * The whole screen while editing; otherwise only the widgets. The regions for
     * the widgets are made as the widgets are, one per widget, and follow them.
     */
    mask: Region {
        id: maskRegion

        x: 0
        y: 0
        width: win.editing ? win.width : 0
        height: win.editing ? win.height : 0
        // Hidden widgets take no clicks.
        regions: win.shown ? win.hits : []
    }

    property var hits: []

    function rebuildHits() {
        const next = [];
        for (let i = 0; i < frames.count; i++) {
            const f = frames.itemAt(i);
            if (f)
                next.push(hitRegion.createObject(maskRegion, { item: f }));
        }
        const old = win.hits;
        win.hits = next;
        for (const r of old)
            r.destroy();
    }

    Component {
        id: hitRegion

        Region {}
    }

    FocusScope {
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Widgets.editing = false

        // Edit mode darkens the desktop a little, so the widgets and the grid read.
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: win.editing ? 0.38 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.standard
                }
            }

            // A click on bare desktop closes any open options.
            TapHandler {
                enabled: win.editing
                onTapped: win.optionsFor = ""
            }
        }

        Item {
            id: field

            x: win.fieldLeft
            y: win.fieldTop
            width: win.cols * win.cell
            height: win.rows * win.cell

            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.97
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.sheetMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.sheetMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            // The grid, as a dot at each corner of a cell.
            Canvas {
                anchors.fill: parent
                opacity: win.editing ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.standard
                    }
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.fillStyle = "rgba(255,255,255,0.22)";
                    ctx.beginPath();
                    for (let y = 0; y <= height; y += win.cell) {
                        for (let x = 0; x <= width; x += win.cell) {
                            ctx.moveTo(x + 1.1, y);
                            ctx.arc(x, y, 1.1, 0, 2 * Math.PI);
                        }
                    }
                    ctx.fill();
                }
            }

            Repeater {
                id: frames

                model: win.items
                onItemAdded: Qt.callLater(win.rebuildHits)
                onItemRemoved: Qt.callLater(win.rebuildHits)

                Item {
                    id: frame

                    required property var modelData

                    readonly property var def: Widgets.types[frame.modelData.type] ?? Widgets.types.clock
                    readonly property bool round: frame.def.shape === "round"
                    readonly property string look: Widgets.option(frame.modelData, "style")
                    readonly property real corner: frame.round ? Math.min(width, height) / 2 : Math.max(Theme.rTile, Math.min(44, Math.min(width, height) * 0.17))
                    // While resizing, the size follows the pointer; otherwise it is
                    // the layout's.
                    property real liveW: -1
                    property real liveH: -1
                    property real grabW: 0
                    property real grabH: 0

                    x: frame.modelData.x * win.cell
                    y: frame.modelData.y * win.cell
                    width: frame.liveW >= 0 ? frame.liveW : frame.modelData.w * win.cell
                    height: frame.liveH >= 0 ? frame.liveH : frame.modelData.h * win.cell
                    z: win.optionsFor === frame.modelData.id ? 20 : 0

                    // Out of edit mode, holding a widget is the way into edit mode.
                    TapHandler {
                        enabled: !win.editing
                        longPressThreshold: 0.6
                        onLongPressed: Widgets.editing = true
                    }

                    // The part that is dragged; the frame keeps its place by binding.
                    Item {
                        id: mover

                        width: frame.width
                        height: frame.height
                        z: drag.active ? 10 : 0
                        scale: drag.active ? 1.02 : 1

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

                        // The tile, for the tile style.
                        Rectangle {
                            anchors.fill: parent
                            radius: frame.corner
                            color: Theme.surface
                            visible: frame.look === "tile"
                        }

                        /*
                         * The widget. In the shadow style it carries a soft dark
                         * shadow of its own shape, which is what keeps white text
                         * legible over a pale part of the wallpaper.
                         */
                        Loader {
                            id: content

                            anchors.fill: parent
                            sourceComponent: win.componentFor(frame.modelData.type)

                            onLoaded: {
                                item.item = Qt.binding(() => frame.modelData);
                                item.live = Qt.binding(() => win.live);
                            }

                            layer.enabled: frame.look === "shadow"
                            layer.effect: MultiEffect {
                                autoPaddingEnabled: true
                                shadowEnabled: true
                                shadowColor: "#000000"
                                shadowOpacity: 0.9
                                shadowBlur: 0.8
                                shadowVerticalOffset: 2
                                shadowHorizontalOffset: 0
                            }
                        }

                        // What marks a widget as movable.
                        Rectangle {
                            anchors.fill: parent
                            radius: frame.corner
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.outline
                            opacity: win.editing ? 1 : 0
                            visible: opacity > 0.01

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.standard
                                }
                            }
                        }

                        DragHandler {
                            id: drag

                            enabled: win.editing
                            target: mover

                            onActiveChanged: {
                                if (active) {
                                    win.optionsFor = "";
                                    return;
                                }
                                const w = frame.modelData.w;
                                const h = frame.modelData.h;
                                const nx = Math.max(0, Math.min(win.cols - w, Math.round((frame.x + mover.x) / win.cell)));
                                const ny = Math.max(0, Math.min(win.rows - h, Math.round((frame.y + mover.y) / win.cell)));
                                mover.x = 0;
                                mover.y = 0;
                                Widgets.move(win.monitor.name, win.cols, frame.modelData.id, nx, ny);
                            }
                        }

                        // Options and removal, at the top right.
                        Row {
                            visible: win.editing
                            x: parent.width - width - (frame.round ? parent.width * 0.15 : 8)
                            y: frame.round ? parent.height * 0.08 : 8
                            spacing: 6

                            CornerButton {
                                icon: "settings"
                                fill: win.optionsFor === frame.modelData.id ? Theme.fg : Theme.surfaceTop
                                ink: win.optionsFor === frame.modelData.id ? Theme.bg : Theme.fg
                                onClicked: win.optionsFor = win.optionsFor === frame.modelData.id ? "" : frame.modelData.id
                            }

                            CornerButton {
                                icon: "close"
                                fill: Theme.accent
                                ink: Theme.bg
                                onClicked: {
                                    win.optionsFor = "";
                                    Widgets.remove(win.monitor.name, win.cols, frame.modelData.id);
                                }
                            }
                        }

                        // The corner that resizes. A MouseArea that will not be
                        // stolen from, so the drag above does not also take it.
                        Rectangle {
                            visible: win.editing
                            x: parent.width - width - (frame.round ? parent.width * 0.15 : 8)
                            y: parent.height - height - (frame.round ? parent.height * 0.15 : 8)
                            width: 18
                            height: 18
                            radius: 9
                            color: Theme.fg

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                preventStealing: true
                                cursorShape: Qt.SizeFDiagCursor

                                property real startX: 0
                                property real startY: 0

                                onPressed: mouse => {
                                    const p = mapToItem(field, mouse.x, mouse.y);
                                    startX = p.x;
                                    startY = p.y;
                                    frame.grabW = frame.width;
                                    frame.grabH = frame.height;
                                    win.optionsFor = "";
                                }

                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return;
                                    const p = mapToItem(field, mouse.x, mouse.y);
                                    const snap = v => Math.round(v / win.cell) * win.cell;
                                    frame.liveW = Math.max(frame.def.minW * win.cell, snap(frame.grabW + p.x - startX));
                                    frame.liveH = Math.max(frame.def.minH * win.cell, snap(frame.grabH + p.y - startY));
                                    // A disc stays a disc.
                                    if (frame.round)
                                        frame.liveH = frame.liveW;
                                }

                                onReleased: {
                                    if (frame.liveW < 0)
                                        return;
                                    const w = frame.liveW / win.cell;
                                    const h = frame.liveH / win.cell;
                                    frame.liveW = -1;
                                    frame.liveH = -1;
                                    Widgets.resize(win.monitor.name, win.cols, frame.modelData.id, w, h);
                                }
                            }
                        }
                    }

                    // This widget's options, beside it.
                    Rectangle {
                        id: options

                        readonly property var list: [Widgets.styleOption].concat(frame.def.options ?? [])
                        readonly property bool open: win.optionsFor === frame.modelData.id
                        // To the right if it fits, otherwise to the left.
                        readonly property bool onRight: frame.x + frame.width + 12 + width < field.width

                        x: options.onRight ? frame.width + 12 : -width - 12
                        y: Math.max(-frame.y, Math.min(0, field.height - frame.y - height))
                        width: optionsBody.implicitWidth + Theme.space(4) * 2
                        height: optionsBody.implicitHeight + Theme.space(4) * 2
                        radius: Theme.rTile
                        color: Theme.deep
                        border.width: 1
                        border.color: Theme.outline
                        opacity: options.open ? 1 : 0
                        visible: opacity > 0.01
                        scale: options.open ? 1 : 0.96

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.standard
                            }
                        }

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.standard
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.soft
                            }
                        }

                        Column {
                            id: optionsBody

                            anchors.centerIn: parent
                            spacing: Theme.space(3)

                            SectionLabel {
                                text: frame.def.label
                                color: Theme.fgBright
                            }

                            Repeater {
                                model: options.list

                                Column {
                                    id: optionRow

                                    required property var modelData

                                    spacing: Theme.space(1)

                                    SectionLabel {
                                        text: optionRow.modelData.label
                                        color: Theme.fgDim
                                    }

                                    Segmented {
                                        model: optionRow.modelData.values
                                        current: Math.max(0, optionRow.modelData.values.indexOf(Widgets.option(frame.modelData, optionRow.modelData.key)))
                                        onPicked: index => Widgets.setOption(win.monitor.name, win.cols, frame.modelData.id,
                                            optionRow.modelData.key, optionRow.modelData.values[index])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        /*
         * The gallery: every widget there is, shown as itself, down the right-hand
         * side. Clicking one adds it to the desktop. See-through and narrow, so the
         * desktop being arranged stays in view behind it, and it folds away to a
         * tab when it is in the way.
         */
        Item {
            id: gallery

            property bool folded: false

            readonly property real panelWidth: 300

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 24
            anchors.bottomMargin: 24
            width: panelWidth
            x: !(win.editing && win.focused) ? win.width + 40 : (gallery.folded ? win.width - 18 : win.width - panelWidth - 16)
            visible: x < win.width + 30

            Behavior on x {
                NumberAnimation {
                    duration: Theme.sheetMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            // The tab it folds to.
            Rectangle {
                anchors.right: panel.left
                anchors.rightMargin: -1
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 64
                radius: 11
                color: Qt.alpha(Theme.deep, 0.85)
                border.width: 1
                border.color: Theme.outline

                Glyph {
                    anchors.centerIn: parent
                    name: "chevron-left"
                    size: 14
                    rotation: gallery.folded ? 0 : 180
                    color: Theme.fg
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: gallery.folded = !gallery.folded
                }
            }

            Rectangle {
                id: panel

                anchors.fill: parent
                radius: Theme.rSheet
                color: Qt.alpha(Theme.deep, 0.78)
                border.width: 1
                border.color: Theme.outline

                Column {
                    id: head

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Theme.space(4)
                    spacing: Theme.space(2)

                    Row {
                        width: parent.width
                        spacing: Theme.space(2)

                        SectionLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - resetChip.width - doneChip.width - Theme.space(2) * 2
                            text: "widgets"
                            color: Theme.fgBright
                        }

                        Rectangle {
                            id: resetChip

                            width: resetLabel.implicitWidth + Theme.space(4)
                            height: 30
                            radius: 15
                            color: resetHover.hovered ? Theme.surfaceTop : "transparent"

                            SectionLabel {
                                id: resetLabel

                                anchors.centerIn: parent
                                text: "reset"
                                color: Theme.fgBright
                            }

                            HoverHandler {
                                id: resetHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: Widgets.reset(win.monitor.name)
                            }
                        }

                        Rectangle {
                            id: doneChip

                            width: doneLabel.implicitWidth + Theme.space(5)
                            height: 30
                            radius: 15
                            color: Theme.fg

                            SectionLabel {
                                id: doneLabel

                                anchors.centerIn: parent
                                text: "done"
                                color: Theme.bg
                            }

                            TapHandler {
                                onTapped: Widgets.editing = false
                            }
                        }
                    }

                    SectionLabel {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: "click to add · drag to move · corner to resize"
                        color: Theme.fgDim
                    }
                }

                Flickable {
                    anchors.top: head.bottom
                    anchors.topMargin: Theme.space(3)
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.space(3)
                    clip: true
                    contentHeight: entries.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: entries

                        x: Theme.space(4)
                        width: parent.width - Theme.space(4) * 2
                        spacing: Theme.space(4)

                        Repeater {
                            model: win.editing ? Widgets.typeNames : []

                            Column {
                                id: entry

                                required property string modelData

                                readonly property var def: Widgets.types[entry.modelData]
                                readonly property real fullW: entry.def.w * win.cell
                                readonly property real fullH: entry.def.h * win.cell
                                readonly property real shrink: Math.min(1, entries.width / entry.fullW, 150 / entry.fullH)

                                width: entries.width
                                spacing: Theme.space(2)

                                // The widget itself, scaled down to fit.
                                Item {
                                    width: entries.width
                                    height: entry.fullH * entry.shrink
                                    scale: entryTap.pressed ? 0.97 : (entryHover.hovered ? 1.02 : 1)

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Theme.standard
                                            easing.type: Easing.Bezier
                                            easing.bezierCurve: Theme.gentle
                                        }
                                    }

                                    Item {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: entry.fullW * entry.shrink
                                        height: entry.fullH * entry.shrink

                                        Item {
                                            width: entry.fullW
                                            height: entry.fullH
                                            scale: entry.shrink
                                            transformOrigin: Item.TopLeft

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: entry.def.shape === "round" ? width / 2 : 40
                                                color: Theme.surface
                                                border.width: 1
                                                border.color: entryHover.hovered ? Theme.outline : Theme.line
                                            }

                                            Loader {
                                                anchors.fill: parent
                                                sourceComponent: win.componentFor(entry.modelData)
                                                onLoaded: {
                                                    item.item = { type: entry.modelData, opts: {} };
                                                    item.live = true;
                                                }
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        id: entryHover

                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        id: entryTap

                                        onTapped: Widgets.add(win.monitor.name, win.cols, entry.modelData)
                                    }
                                }

                                SectionLabel {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: entry.def.label
                                    color: Theme.fgBright
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component CornerButton: Rectangle {
        id: corner

        property string icon: ""
        property color fill: Theme.surfaceTop
        property color ink: Theme.fg

        signal clicked

        width: 24
        height: 24
        radius: 12
        color: corner.fill

        Glyph {
            anchors.centerIn: parent
            name: corner.icon
            size: 12
            stroke: 2
            color: corner.ink
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: corner.clicked()
        }
    }

    Component {
        id: clockWidget

        ClockWidget {}
    }

    Component {
        id: greetingWidget

        GreetingWidget {}
    }

    Component {
        id: weatherWidget

        WeatherWidget {}
    }

    Component {
        id: dateWidget

        DateWidget {}
    }

    Component {
        id: gpuWidget

        GpuWidget {}
    }

    Component {
        id: mediaWidget

        MediaWidget {}
    }

    Component {
        id: statsWidget

        StatsWidget {}
    }

    Component {
        id: cpuWidget

        CpuWidget {}
    }

    Component {
        id: memoryWidget

        MemoryWidget {}
    }

    Component {
        id: batteryWidget

        BatteryWidget {}
    }

    Component {
        id: diskWidget

        DiskWidget {}
    }

    Component {
        id: networkWidget

        NetworkWidget {}
    }

    Component {
        id: photoWidget

        PhotoWidget {}
    }
}
