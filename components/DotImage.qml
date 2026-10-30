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
    /*
     * Size each dot by brightness instead of thresholding it on or off. A plain
     * threshold throws away everything between "dark" and "light", which on album
     * art is most of the picture; varying the radius keeps the tonal range at the
     * same dot pitch.
     */
    property bool halftone: false
    // Clip to the inscribed circle, for art shown as a disc.
    property bool circular: false
    /*
     * Each dot takes the colour of the picture under it instead of `dotColor`.
     * Brightness still decides how big the dot is, so the tonal range survives;
     * colour rides on top. A dark pixel would otherwise give a dark dot on a dark
     * surface, so every dot's brightness is lifted to a floor while keeping its
     * hue — the shadows become small, saturated dots rather than disappearing.
     */
    property bool colored: false
    /*
     * Dark art on a light ground, shown the other way round. Dots are light on a
     * dark surface, so a picture with a white background lights the whole disc
     * and leaves its subject as the gaps — line art becomes a blank circle.
     * `autoInvert` flips images whose average is bright and leaves photographs,
     * which are not mostly white, alone.
     */
    property bool invert: false
    property bool autoInvert: false
    // Scales brightness before it sets a dot's size. Thin strokes average out to
    // a faint grey at this resolution and need lifting to stay visible.
    property real gain: 1
    // How bright the dots are drawn, 0 to 1. Separate from `gain`, which scales the
    // brightness that decides a halftone dot's radius and so changes its size.
    property real dotAlpha: 1
    /*
     * Crops to the subject when the picture has a plain ground around it. Avatars
     * drawn on a white square are mostly white square, and at a few dozen dots
     * across the subject is left with half the disc. The ground is taken from the
     * corners, so a photograph — which has no such ground — is left whole.
     */
    property bool frameSubject: false
    /*
     * How the picture meets the grid. "stretch" squeezes it to fill, which is right
     * for a square avatar and wrong for a wallpaper: a 16:9 picture on a 16:10
     * screen comes out taller and narrower than it is, and everything in it moves.
     * "crop" fills the grid from the middle of the picture and cuts the overflow,
     * as the plain wallpaper does.
     */
    property string fit: "stretch"
    /*
     * Stretches the picture's own tones to fill the range before they become dot
     * sizes. Without colour a saturated picture — a blue, say — is nearly black by
     * luma and draws almost no dots, while a pale one draws dots so large they
     * merge into a solid sheet.
     */
    property bool autoLevels: false

    // 4x4 Bayer matrix, normalised. Ordered dithering keeps the dot grid regular,
    // which is the point — error diffusion would scatter it.
    readonly property var bayer: [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]

    /*
     * The picture is read through Images with a small sourceSize, not drawn from
     * the file. Canvas scales by sampling, and squeezing a 700px picture into 34
     * dots that way skips most of the pixels: thin strokes fall between samples
     * and disappear, which turned line art into a blank disc. An Image scaled at
     * decode time averages over the area instead.
     */
    readonly property int cols: Math.max(1, Math.floor(width / cell))
    readonly property int rows: Math.max(1, Math.floor(height / cell))

    implicitWidth: 104
    implicitHeight: 104

    /*
     * A sampled Image is not always drawable the moment it reports Ready: a paint
     * that lands early reads back nothing, and on a lock screen — where the whole
     * surface appears at once — that was every paint, leaving an empty ring where
     * the picture should be. A read that comes back entirely transparent is
     * retried until the pixels are really there, up to about two seconds.
     */
    property int attempts: 0
    // True once dots for the current source are on the canvas.
    property bool drawn: false

    Timer {
        id: retry

        interval: 100
        onTriggered: root.requestPaint()
    }

    onSourceChanged: {
        root.drawn = false;
        root.attempts = 0;
        requestPaint();
    }
    onColsChanged: requestPaint()
    onRowsChanged: requestPaint()
    onDotColorChanged: requestPaint()
    onCellChanged: requestPaint()
    onDotScaleChanged: requestPaint()
    onFitChanged: requestPaint()
    onAutoLevelsChanged: requestPaint()
    onHalftoneChanged: requestPaint()
    onCircularChanged: requestPaint()
    onColoredChanged: requestPaint()
    onInvertChanged: requestPaint()
    onGainChanged: requestPaint()
    onDotAlphaChanged: requestPaint()

    Image {
        id: sampler

        visible: false
        source: root.source
        // Twice the grid: the area average does the heavy reduction, and the last
        // factor of two is a gentle one for the canvas.
        sourceSize: Qt.size(root.cols * 2, root.rows * 2)
        onStatusChanged: if (status === Image.Ready) root.requestPaint()
    }

    Image {
        id: probe

        visible: false
        source: root.frameSubject ? root.source : ""
        sourceSize: Qt.size(96, 96)
        onStatusChanged: if (status === Image.Ready) root.requestPaint()
    }

    function anyDrawn(pixels) {
        for (let k = 3; k < pixels.length; k += 4) {
            if (pixels[k] !== 0)
                return true;
        }
        return false;
    }

    // Try again shortly: the image was reported ready but would not draw yet.
    function again() {
        if (root.attempts < 20) {
            root.attempts++;
            retry.restart();
        }
    }

    // Same hue and saturation, brightness raised to at least `floor`.
    function lifted(r, g, b, floor) {
        const peak = Math.max(r, g, b);
        const want = floor * 255;
        if (peak >= want)
            return `rgb(${r},${g},${b})`;
        // Nothing to take a hue from: a neutral at the floor.
        if (peak < 12)
            return `rgb(${Math.round(want)},${Math.round(want)},${Math.round(want)})`;
        const k = want / peak;
        return `rgb(${Math.min(255, Math.round(r * k))},${Math.min(255, Math.round(g * k))},${Math.min(255, Math.round(b * k))})`;
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (source.length === 0 || sampler.status !== Image.Ready)
            return;
        if (frameSubject && probe.status !== Image.Ready)
            return;
        const cols = root.cols;
        const rows = root.rows;

        // Where the picture is drawn, in units of the grid: the whole of it by
        // default, or enlarged and shifted so the subject fills the grid.
        let ox = 0;
        let oy = 0;
        let dw = cols;
        let dh = rows;
        // What lies past the picture's edge once it has been framed: its own ground.
        let ground = "";

        if (frameSubject) {
            const N = 96;
            ctx.drawImage(probe, 0, 0, N, N);
            const seen = ctx.getImageData(0, 0, N, N).data;
            if (!root.anyDrawn(seen)) {
                root.again();
                return;
            }
            const lumaAt = (px, py) => {
                const k = (py * N + px) * 4;
                return (0.299 * seen[k] + 0.587 * seen[k + 1] + 0.114 * seen[k + 2]) / 255;
            };
            const groundLuma = (lumaAt(0, 0) + lumaAt(N - 1, 0) + lumaAt(0, N - 1) + lumaAt(N - 1, N - 1)) / 4;
            const corner = (c) => (seen[c] + seen[(N - 1) * 4 + c] + seen[(N - 1) * N * 4 + c] + seen[((N - 1) * N + N - 1) * 4 + c]) / 4;
            ground = `rgb(${Math.round(corner(0))},${Math.round(corner(1))},${Math.round(corner(2))})`;
            let x0 = N, y0 = N, x1 = -1, y1 = -1;
            for (let py = 0; py < N; py++) {
                for (let px = 0; px < N; px++) {
                    if (Math.abs(lumaAt(px, py) - groundLuma) > 0.1) {
                        x0 = Math.min(x0, px);
                        y0 = Math.min(y0, py);
                        x1 = Math.max(x1, px);
                        y1 = Math.max(y1, py);
                    }
                }
            }
            if (x1 >= 0) {
                // A square about the subject's centre, a little larger than it.
                const side = Math.max(x1 - x0 + 1, y1 - y0 + 1) * 1.14 / N;
                const cxn = (x0 + x1 + 1) / 2 / N;
                const cyn = (y0 + y1 + 1) / 2 / N;
                if (side < 0.97) {
                    dw = cols / side;
                    dh = rows / side;
                    ox = -(cxn - side / 2) * dw;
                    oy = -(cyn - side / 2) * dh;
                }
            }
            ctx.reset();
        }

        if (fit === "crop" && !frameSubject && sampler.implicitWidth > 0 && sampler.implicitHeight > 0) {
            const nw = sampler.implicitWidth;
            const nh = sampler.implicitHeight;
            const want = cols / rows;
            let sw = nw;
            let sh = nh;
            if (nw / nh > want)
                sw = nh * want;
            else
                sh = nw / want;
            ctx.drawImage(sampler, (nw - sw) / 2, (nh - sh) / 2, sw, sh, 0, 0, cols, rows);
        } else {
            ctx.drawImage(sampler, ox, oy, dw, dh);
        }
        let data = ctx.getImageData(0, 0, cols, rows).data;
        if (!root.anyDrawn(data)) {
            root.again();
            return;
        }
        root.attempts = 0;

        // A subject at the picture's edge — a figure cut off at the bottom — leaves
        // part of the framed square outside the picture. That strip is the ground
        // continuing, not a hole, or the subject sits off-centre in empty dark. It
        // goes underneath, and only after the picture is known to have drawn: laid
        // down first it made an undrawn canvas look drawn.
        if (ground.length > 0) {
            ctx.globalCompositeOperation = "destination-over";
            ctx.fillStyle = ground;
            ctx.fillRect(0, 0, cols, rows);
            ctx.globalCompositeOperation = "source-over";
            data = ctx.getImageData(0, 0, cols, rows).data;
        }
        ctx.reset();

        const radius = cell * dotScale;
        const cx = cols / 2 - 0.5;
        const cy = rows / 2 - 0.5;
        const clipRadius = Math.min(cols, rows) / 2;

        let flip = invert;
        if (autoInvert && !invert) {
            let sum = 0;
            let n = 0;
            for (let y = 0; y < rows; y++) {
                for (let x = 0; x < cols; x++) {
                    if (circular && Math.hypot(x - cx, y - cy) > clipRadius)
                        continue;
                    const j = (y * cols + x) * 4;
                    sum += (0.299 * data[j] + 0.587 * data[j + 1] + 0.114 * data[j + 2]) / 255 * (data[j + 3] / 255);
                    n++;
                }
            }
            flip = n > 0 && sum / n > 0.62;
        }

        // Where the picture's tones start and end, so mono can use the whole range.
        let lo = 0;
        let hi = 1;
        if (autoLevels) {
            const bins = new Array(64).fill(0);
            let total = 0;
            for (let k = 0; k < rows * cols; k++) {
                const j = k * 4;
                const l = (0.299 * data[j] + 0.587 * data[j + 1] + 0.114 * data[j + 2]) / 255 * (data[j + 3] / 255);
                bins[Math.min(63, Math.floor(l * 64))]++;
                total++;
            }
            let run = 0;
            let found = false;
            for (let b = 0; b < 64; b++) {
                run += bins[b];
                if (!found && run > total * 0.02) {
                    lo = b / 64;
                    found = true;
                }
                if (run > total * 0.98) {
                    hi = (b + 1) / 64;
                    break;
                }
            }
        }

        ctx.fillStyle = dotColor;
        ctx.globalAlpha = Math.max(0.05, Math.min(1, dotAlpha));

        for (let y = 0; y < rows; y++) {
            for (let x = 0; x < cols; x++) {
                if (circular && Math.hypot(x - cx, y - cy) > clipRadius)
                    continue;

                const i = (y * cols + x) * 4;
                // Rec. 601 luma, matching how the rest of the shell weighs colour.
                let luma = (0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2]) / 255;
                if (autoLevels)
                    luma = Math.max(0, Math.min(1, (luma - lo) / Math.max(0.12, hi - lo)));
                const alpha = data[i + 3] / 255;
                // Inverted, an empty (transparent) pixel stays empty rather than lighting up.
                const v = Math.min(1, (flip ? (1 - luma) * alpha : luma * alpha) * gain);

                let r;
                if (halftone) {
                    // Square root, not the value itself: dot area grows with the
                    // square of the radius, so a linear radius darkens the
                    // midtones well past where they should be.
                    r = radius * Math.sqrt(v);
                    if (colored)
                        // A coloured dot has to be big enough to show its colour.
                        r = v < 0.04 ? 0 : radius * (0.4 + 0.6 * Math.sqrt(v));
                    if (r < 0.25)
                        continue;
                } else {
                    if (v <= (bayer[y % 4][x % 4] + 0.5) / 16)
                        continue;
                    r = radius;
                }

                if (colored) {
                    // Dark ink on a light ground has no colour worth showing — it is
                    // black — so it takes the dot colour; coloured areas keep theirs.
                    const dark = flip && Math.max(data[i], data[i + 1], data[i + 2]) < 70;
                    ctx.fillStyle = dark ? dotColor : root.lifted(data[i], data[i + 1], data[i + 2], 0.62);
                }

                ctx.beginPath();
                ctx.arc(x * cell + cell / 2, y * cell + cell / 2, r, 0, 2 * Math.PI);
                ctx.fill();
            }
        }
        root.drawn = true;
    }
}
