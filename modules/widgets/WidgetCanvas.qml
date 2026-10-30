pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The desktop's widgets, on the layer just above the wallpaper.
 *
 * Out of edit mode the whole surface is click-through, so the desktop behaves
 * as it always did and widgets are only something to look at. In edit mode it
 * takes the pointer: a grid shows, each widget gets an outline, a corner to
 * resize by and a button to remove it, and dragging moves it, snapping to the grid
 * where it is let go. A bar at the foot adds more.
 *
 * Layout is in grid cells and kept per monitor (services/Widgets.qml).
 */
PanelWindow {
    id: win

    required property ShellScreen monitor

    readonly property bool editing: Widgets.editing
    readonly property bool focused: Hypr.focusedWorkspace?.monitor?.name === win.monitor.name
    readonly property real cell: Widgets.cell

    // Clear of the bar, with a margin.
    readonly property bool barSide: Config.get("bar.orientation", "vertical") === "vertical"
    readonly property real fieldLeft: win.barSide
        ? Config.get("bar.width", 56) + Config.get("bar.margin", 10) * 2 + 16 : 24
    readonly property real fieldTop: win.barSide
        ? 24 : Config.get("bar.height", 38) + Config.get("bar.margin", 10) * 2 + 16
    readonly property int cols: Math.max(10, Math.floor((win.monitor.width - win.fieldLeft - 24) / win.cell))
    readonly property int rows: Math.max(10, Math.floor((win.monitor.height - win.fieldTop - 24) / win.cell))

    readonly property var items: Widgets.layoutFor(win.monitor.name, win.cols)

    function componentFor(type) {
        return ({
            "clock": clockWidget,
            "greeting": greetingWidget,
            "weather": weatherWidget,
            "date": dateWidget,
            "gpu": gpuWidget,
            "media": mediaWidget,
            "stats": statsWidget
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

    mask: Region {
        x: 0
        y: 0
        width: win.editing ? win.width : 0
        height: win.editing ? win.height : 0
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
        }

        Item {
            id: field

            x: win.fieldLeft
            y: win.fieldTop
            width: win.cols * win.cell
            height: win.rows * win.cell

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
                    for (let y = 0; y <= height; y += win.cell) {
                        for (let x = 0; x <= width; x += win.cell) {
                            ctx.beginPath();
                            ctx.arc(x, y, 1.1, 0, 2 * Math.PI);
                            ctx.fill();
                        }
                    }
                }
            }

            Repeater {
                model: win.items

                Item {
                    id: frame

                    required property var modelData

                    readonly property var def: Widgets.types[frame.modelData.type]
                    readonly property bool round: frame.def.shape === "round"
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

                        Rectangle {
                            anchors.fill: parent
                            radius: frame.round ? Math.min(width, height) / 2 : Theme.rTile
                            color: frame.def.shape === "none" ? "transparent" : Theme.surface
                            border.width: frame.def.shape === "none" ? 0 : 1
                            border.color: Theme.line
                        }

                        Loader {
                            anchors.fill: parent
                            sourceComponent: win.componentFor(frame.modelData.type)
                        }

                        // What marks a widget as movable.
                        Rectangle {
                            anchors.fill: parent
                            radius: frame.round ? Math.min(width, height) / 2 : Theme.rTile
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
                                if (active)
                                    return;
                                const w = frame.modelData.w;
                                const h = frame.modelData.h;
                                const nx = Math.max(0, Math.min(win.cols - w, Math.round((frame.x + mover.x) / win.cell)));
                                const ny = Math.max(0, Math.min(win.rows - h, Math.round((frame.y + mover.y) / win.cell)));
                                mover.x = 0;
                                mover.y = 0;
                                Widgets.move(win.monitor.name, win.cols, frame.modelData.id, nx, ny);
                            }
                        }

                        // Take it off the desktop.
                        Rectangle {
                            visible: win.editing
                            x: parent.width - width - 6
                            y: 6
                            width: 22
                            height: 22
                            radius: 11
                            color: Theme.accent

                            Glyph {
                                anchors.centerIn: parent
                                name: "close"
                                size: 11
                                stroke: 2.2
                                color: Theme.bg
                            }

                            TapHandler {
                                onTapped: Widgets.remove(win.monitor.name, win.cols, frame.modelData.id)
                            }
                        }

                        // The corner that resizes. A MouseArea that will not be
                        // stolen from, so the drag above does not also take it.
                        Rectangle {
                            visible: win.editing
                            x: parent.width - width - 6
                            y: parent.height - height - 6
                            width: 20
                            height: 20
                            radius: 10
                            color: Theme.fg

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
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
                                }

                                onPositionChanged: mouse => {
                                    if (!pressed)
                                        return;
                                    const p = mapToItem(field, mouse.x, mouse.y);
                                    const snap = v => Math.round(v / win.cell) * win.cell;
                                    frame.liveW = Math.max(frame.def.minW * win.cell, snap(frame.grabW + p.x - startX));
                                    frame.liveH = Math.max(frame.def.minH * win.cell, snap(frame.grabH + p.y - startY));
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
                }
            }
        }

        // How to use it, and the way to add and finish.
        Rectangle {
            id: bar

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 36
            width: palette.implicitWidth + Theme.space(5) * 2
            height: 56
            radius: height / 2
            color: Theme.deep
            border.width: 1
            border.color: Theme.outline
            opacity: win.editing && win.focused ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.standard
                }
            }

            Row {
                id: palette

                anchors.centerIn: parent
                spacing: Theme.space(2)

                SectionLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "add"
                    color: Theme.fgBright
                    rightPadding: Theme.space(1)
                }

                Repeater {
                    model: Widgets.typeNames

                    Rectangle {
                        id: chip

                        required property string modelData

                        width: chipRow.implicitWidth + Theme.space(4)
                        height: 34
                        radius: height / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: chipHover.hovered ? Theme.surfaceTop : Theme.surfaceHi

                        Row {
                            id: chipRow

                            anchors.centerIn: parent
                            spacing: Theme.space(2)

                            Glyph {
                                anchors.verticalCenter: parent.verticalCenter
                                name: Widgets.types[chip.modelData].icon
                                size: 14
                                color: Theme.fg
                            }

                            SectionLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: Widgets.types[chip.modelData].label
                                color: Theme.fg
                            }
                        }

                        HoverHandler {
                            id: chipHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: Widgets.add(win.monitor.name, win.cols, chip.modelData)
                        }
                    }
                }

                Rectangle {
                    width: resetLabel.implicitWidth + Theme.space(4)
                    height: 34
                    radius: 17
                    anchors.verticalCenter: parent.verticalCenter
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
                    width: doneLabel.implicitWidth + Theme.space(5)
                    height: 34
                    radius: 17
                    anchors.verticalCenter: parent.verticalCenter
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
        }

        SectionLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: bar.top
            anchors.bottomMargin: Theme.space(3)
            text: "drag to move · corner to resize · esc when done"
            color: Theme.fgBright
            opacity: bar.opacity
            visible: bar.visible
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
}
