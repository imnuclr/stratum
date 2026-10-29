import QtQuick
import qs.theme

/*
 * Ordered-dither any image into dots — album art, avatars, wallpaper thumbnails.
 *
 * Runs on a Canvas rather than a shader because it only re-renders when the
 * source changes, which for album art is once a track. Phase 4 moves this to a
 * fragment shader once qt6-shadertools is a dependency; the interface stays.
 */
Canvas {
    id: root

    property string source: ""
    property real cell: 4
    property real dotScale: 0.38
    property color dotColor: Theme.dotOn

    // 4x4 Bayer matrix, normalised. Ordered dithering keeps the dot grid regular,
    // which is the point — error diffusion would scatter it.
    readonly property var bayer: [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

    implicitWidth: 104
    implicitHeight: 104

    onSourceChanged: {
        if (source.length === 0) {
            requestPaint();
            return;
        }
        loadImage(source);
    }

    onImageLoaded: requestPaint()
    onDotColorChanged: requestPaint()
    onCellChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        if (source.length === 0 || !isImageLoaded(source))
            return;

        const cols = Math.floor(width / cell);
        const rows = Math.floor(height / cell);
        if (cols < 1 || rows < 1)
            return;

        // Draw the source down to one pixel per dot, then read it back, so the
        // sampling is the scaler's job rather than ours.
        ctx.drawImage(source, 0, 0, cols, rows);
        const data = ctx.getImageData(0, 0, cols, rows).data;
        ctx.reset();

        ctx.fillStyle = dotColor;
        const radius = cell * dotScale;

        for (let y = 0; y < rows; y++) {
            for (let x = 0; x < cols; x++) {
                const i = (y * cols + x) * 4;
                // Rec. 601 luma, matching how the rest of the shell weighs colour.
                const luma = (0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2]) / 255;
                const alpha = data[i + 3] / 255;

                if (luma * alpha > (bayer[y % 4][x % 4] + 0.5) / 16) {
                    ctx.beginPath();
                    ctx.arc(x * cell + cell / 2, y * cell + cell / 2, radius, 0, 2 * Math.PI);
                    ctx.fill();
                }
            }
        }
    }
}
