import QtQuick
import qs.theme

/*
 * What stands in for album art when a player sends none: a disc of faint dots,
 * densest at the middle, with a dotted pair of headphones — the same material as
 * a dithered cover, so the card looks finished rather than missing its picture.
 * Used wherever now playing is shown.
 */
Canvas {
    id: blank

    onWidthChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const g = 30;
        const cell = width / g;
        const r = width / 2;
        for (let y = 0; y < g; y++) {
            for (let x = 0; x < g; x++) {
                const cx = x * cell + cell / 2;
                const cy = y * cell + cell / 2;
                const d = Math.hypot(cx - r, cy - r) / r;
                if (d > 0.97)
                    continue;
                ctx.fillStyle = `rgba(255,255,255,${0.07 + 0.11 * (1 - d)})`;
                ctx.beginPath();
                ctx.arc(cx, cy, cell * 0.3, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
    }

    DotIcon {
        anchors.centerIn: parent
        width: parent.width * 0.36
        height: width
        name: "headphones"
        color: Theme.fgBright
    }
}
