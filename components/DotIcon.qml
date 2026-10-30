import QtQuick
import qs.theme
import qs.utils

/*
 * One of the stroke icons, redrawn as a field of fine dots.
 *
 * The icon is drawn small and solid, read back a pixel per dot, and every pixel
 * the line passes through becomes a dot — so a cloud is a cloud's outline made of
 * dots, the way the dot-matrix numerals are made, rather than a bitmap of a few
 * coarse blocks.
 */
Canvas {
    id: root

    property string name: ""
    // Dots across the icon. More is finer.
    property int grid: 30
    // The line's weight, in the icon's own 24-unit grid.
    property real stroke: 1.35
    property color color: Theme.fg

    implicitWidth: 64
    implicitHeight: 64

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onGridChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (root.name.length === 0)
            return;
        const g = root.grid;

        ctx.save();
        ctx.scale(g / 24, g / 24);
        ctx.lineWidth = root.stroke;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = "#ffffff";
        ctx.path = Icons.path(root.name);
        ctx.stroke();
        ctx.restore();

        const data = ctx.getImageData(0, 0, g, g).data;
        ctx.reset();

        const cell = Math.min(root.width, root.height) / g;
        ctx.fillStyle = root.color;
        ctx.beginPath();
        for (let y = 0; y < g; y++) {
            for (let x = 0; x < g; x++) {
                const a = data[(y * g + x) * 4 + 3] / 255;
                if (a < 0.3)
                    continue;
                const r = cell * 0.36 * (0.65 + 0.35 * a);
                const cx = x * cell + cell / 2;
                const cy = y * cell + cell / 2;
                ctx.moveTo(cx + r, cy);
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            }
        }
        ctx.fill();
    }
}
