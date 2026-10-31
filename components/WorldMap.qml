import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

/*
 * A world map to point at: country outlines as white lines on dark grey, a
 * faint graticule, and a pin. Drag to move, scroll to zoom, click to choose.
 *
 * The outlines are Natural Earth's 1:50m countries (public domain), simplified
 * and stored as tenths of a degree in assets/map/world.json. Drawn flat
 * (equirectangular): for picking a town it is all that is needed, and it keeps
 * the arithmetic to a multiply.
 */
Item {
    id: root

    // Where the map is looking, and how close: 1 shows the whole world.
    property real centerLat: 20
    property real centerLon: 0
    property real zoom: 1
    // The chosen point, NaN for none.
    property real pinLat: NaN
    property real pinLon: NaN

    signal picked(real lat, real lon)

    property var rings: []

    readonly property real scale: root.width / 360 * root.zoom

    function toX(lon) {
        return root.width / 2 + (lon - root.centerLon) * root.scale;
    }

    function toY(lat) {
        return root.height / 2 - (lat - root.centerLat) * root.scale;
    }

    function lonAt(x) {
        return root.centerLon + (x - root.width / 2) / root.scale;
    }

    function latAt(y) {
        return root.centerLat - (y - root.height / 2) / root.scale;
    }

    function clampView() {
        root.zoom = Math.max(1, Math.min(60, root.zoom));
        const halfH = root.height / 2 / root.scale;
        root.centerLat = Math.max(-90 + halfH, Math.min(90 - halfH, root.centerLat));
        root.centerLon = ((root.centerLon + 540) % 360) - 180;
    }

    // Brings a point into the middle, close enough to see the town.
    function show(lat, lon, closeness) {
        root.zoom = closeness ?? 14;
        root.centerLat = lat;
        root.centerLon = lon;
        root.clampView();
        canvas.requestPaint();
    }

    onCenterLatChanged: canvas.requestPaint()
    onCenterLonChanged: canvas.requestPaint()
    onZoomChanged: canvas.requestPaint()
    onPinLatChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()
    onHeightChanged: canvas.requestPaint()

    FileView {
        path: Quickshell.shellPath("assets/map/world.json")
        preload: true
        onLoaded: {
            try {
                root.rings = JSON.parse(text());
            } catch (e) {
                root.rings = [];
            }
            canvas.requestPaint();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.rTile
        color: "#141414"
        border.width: 1
        border.color: Theme.line
    }

    Canvas {
        id: canvas

        anchors.fill: parent
        anchors.margins: 1
        renderStrategy: Canvas.Threaded

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.save();
            // Round corners, to match the frame.
            const r = Theme.rTile - 1;
            ctx.beginPath();
            ctx.roundedRect(0, 0, width, height, r, r);
            ctx.clip();

            // The graticule, every 30 degrees, barely there.
            ctx.strokeStyle = "rgba(255,255,255,0.06)";
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (let lon = -180; lon <= 180; lon += 30) {
                const x = root.toX(lon);
                ctx.moveTo(x, root.toY(90));
                ctx.lineTo(x, root.toY(-90));
            }
            for (let lat = -60; lat <= 60; lat += 30) {
                const y = root.toY(lat);
                ctx.moveTo(root.toX(-180), y);
                ctx.lineTo(root.toX(180), y);
            }
            ctx.stroke();

            // The countries. Drawn three times across so panning past the
            // date line keeps showing land.
            ctx.strokeStyle = "rgba(255,255,255,0.62)";
            ctx.lineWidth = root.zoom > 6 ? 1.2 : 0.9;
            ctx.lineJoin = "round";
            ctx.beginPath();
            const k = root.scale / 10;
            const ox = root.width / 2 - root.centerLon * root.scale;
            const oy = root.height / 2 + root.centerLat * root.scale;
            for (const shift of [-3600, 0, 3600]) {
                const sx = ox + shift * k;
                if (sx + 1800 * k < 0 || sx - 1800 * k > width)
                    continue;
                for (const ring of root.rings) {
                    ctx.moveTo(sx + ring[0] * k, oy - ring[1] * k);
                    for (let i = 2; i < ring.length; i += 2)
                        ctx.lineTo(sx + ring[i] * k, oy - ring[i + 1] * k);
                }
            }
            ctx.stroke();

            // The pin: the accent, in a ring.
            if (!isNaN(root.pinLat)) {
                const px = root.toX(root.pinLon);
                const py = root.toY(root.pinLat);
                ctx.fillStyle = Theme.accent;
                ctx.beginPath();
                ctx.arc(px, py, 5, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = "rgba(255,255,255,0.9)";
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                ctx.arc(px, py, 10, 0, Math.PI * 2);
                ctx.stroke();
            }
            ctx.restore();
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: pressed && moved ? Qt.ClosedHandCursor : Qt.CrossCursor

        property real lastX: 0
        property real lastY: 0
        property bool moved: false

        onPressed: event => {
            lastX = event.x;
            lastY = event.y;
            moved = false;
        }
        onPositionChanged: event => {
            if (!pressed)
                return;
            const dx = event.x - lastX;
            const dy = event.y - lastY;
            if (Math.abs(dx) + Math.abs(dy) > 2)
                moved = true;
            root.centerLon -= dx / root.scale;
            root.centerLat += dy / root.scale;
            root.clampView();
            lastX = event.x;
            lastY = event.y;
        }
        onReleased: event => {
            if (!moved)
                root.picked(root.latAt(event.y), ((root.lonAt(event.x) + 540) % 360) - 180);
        }
        // Zooms about the point under the pointer, so it stays under it.
        onWheel: event => {
            const lat = root.latAt(event.y);
            const lon = root.lonAt(event.x);
            root.zoom *= event.angleDelta.y > 0 ? 1.25 : 0.8;
            root.clampView();
            root.centerLon += lon - root.lonAt(event.x);
            root.centerLat += lat - root.latAt(event.y);
            root.clampView();
        }
    }

    // Zoom buttons, for a touchpad without a scroll gesture.
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.space(3)
        spacing: Theme.space(1)

        Repeater {
            model: [["+", 1.5], ["−", 1 / 1.5]]

            Rectangle {
                required property var modelData

                width: 30
                height: 30
                radius: 15
                color: zoomHover.hovered ? "#2A2A2A" : "#1E1E1E"
                border.width: 1
                border.color: "#33FFFFFF"

                Text {
                    anchors.centerIn: parent
                    text: modelData[0]
                    color: "#FFFFFF"
                    font.family: Theme.fontUi
                    font.pixelSize: 16
                    renderType: Text.NativeRendering
                }

                HoverHandler {
                    id: zoomHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: {
                        root.zoom *= modelData[1];
                        root.clampView();
                    }
                }
            }
        }
    }
}
