import QtQuick
import QtQuick.Effects
import qs.config
import qs.services
import qs.theme

/*
 * One wallpaper layer, drawn in whichever look is chosen: the picture as it is,
 * or halftone dots. `mono` takes the colour out of either.
 *
 * The dots are a fragment shader (assets/shaders/dots.frag) reading the same image
 * the plain look shows. They used to be drawn dot by dot on a canvas, tens of
 * thousands of them on the CPU each time anything changed, which made switching
 * wallpaper and turning the rings stall the whole shell. Now the picture is
 * uploaded once and everything else — grid, size, light, mono — is a number
 * handed to the shader, so it costs the same as showing the picture.
 */
Item {
    id: root

    property url source
    property int pixelWidth: 1920
    property int pixelHeight: 1080
    property string look: "original"
    property bool mono: false
    // Grid pitch in pixels, and a dot's radius as a share of it (kept under half
    // so neighbouring dots do not merge into a solid sheet).
    property real dotSize: 8
    property real dotScale: 0.5
    // 0 to 1: how bright the dots are drawn. Their size is a separate setting.
    property real light: 1

    // The tones the picture really spans, so mono can use the whole range: a
    // saturated blue is nearly black by luma and would otherwise draw almost
    // nothing. Worked out from a small copy of the picture.
    property real lo: 0
    property real hi: 1

    signal ready

    // Colour taken out of the picture itself, for the plain look.
    layer.enabled: root.mono && root.look === "original"
    layer.effect: MultiEffect {
        saturation: -1
    }

    // The ground the dots are drawn on. Opaque, so a layer fading in covers the one
    // beneath completely and the crossfade has no see-through gaps.
    Rectangle {
        anchors.fill: parent
        color: Theme.wall
        visible: root.dotsDrawn
    }

    Image {
        id: picture

        anchors.fill: parent
        // Read by the shader too, which works whether or not it is shown; shown
        // itself when the dots cannot be drawn.
        visible: root.look === "original" || (root.look === "dots" && !root.dotsDrawn)
        fillMode: Image.PreserveAspectCrop
        // Cropped to this monitor rather than scaled to a common size: the
        // 3440x1440 and the 1920x1080 want different parts of the same file.
        sourceSize.width: root.pixelWidth
        sourceSize.height: root.pixelHeight
        asynchronous: true
        // Kept, so going back to a picture already seen is instant, and so the
        // picker can have its neighbours decoded before they are asked for.
        cache: true
        // The shader averages the cell itself, from the picture as it is.
        mipmap: false

        onStatusChanged: {
            if (status === Image.Ready) {
                probe.attempts = 0;
                probe.requestPaint();
                root.ready();
            }
        }
    }

    /*
     * The dots, drawn on the GPU. Where that fails — a driver with no shader
     * dialect in common with the compiled file, or a card that refuses it — the
     * picture itself is shown instead: a wallpaper that is not dotted is a
     * disappointment, a black screen is a fault. `wallpaper.shader: false`
     * forces the plain picture everywhere.
     */
    property bool shaderBroken: false
    readonly property bool dotsDrawn: root.look === "dots" && !root.shaderBroken
        && Config.get("wallpaper.shader", true)

    ShaderEffect {
        id: dots

        anchors.fill: parent
        visible: root.dotsDrawn
        fragmentShader: Qt.resolvedUrl("../../assets/shaders/dots.frag.qsb")

        onStatusChanged: {
            if (dots.status === ShaderEffect.Error) {
                root.shaderBroken = true;
                Diag.log("wallpaper", `dots shader refused: ${dots.log}`);
            } else if (dots.status === ShaderEffect.Compiled) {
                root.shaderBroken = false;
            }
        }

        property variant source: picture
        property vector2d size: Qt.vector2d(width, height)

        // The part of the picture that fills this display: a centred crop, by
        // proportion only (the picture's size in pixels is not reliable here).
        readonly property real pictureAspect: picture.implicitWidth > 0 && picture.implicitHeight > 0
            ? picture.implicitWidth / picture.implicitHeight : 1
        readonly property real viewAspect: height > 0 ? width / height : 1
        property vector2d uvScale: pictureAspect > viewAspect
            ? Qt.vector2d(viewAspect / pictureAspect, 1)
            : Qt.vector2d(1, pictureAspect / viewAspect)
        property vector2d uvOffset: Qt.vector2d((1 - uvScale.x) / 2, (1 - uvScale.y) / 2)

        property real cell: Math.max(2, root.dotSize)
        property real dotScale: Math.min(0.5, root.dotScale)
        property real light: Math.max(0.05, Math.min(1, root.light))
        property real mono: root.mono ? 1 : 0
        property real lo: root.lo
        property real hi: root.hi
        property real ink: Theme.dark ? 0 : 1
    }

    // A small copy of the picture, read for its tones.
    Canvas {
        id: probe

        property int attempts: 0

        width: 96
        height: 54
        visible: false

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (picture.status !== Image.Ready)
                return;
            ctx.drawImage(picture, 0, 0, width, height);
            const data = ctx.getImageData(0, 0, width, height).data;
            const bins = new Array(64).fill(0);
            let total = 0;
            for (let i = 0; i < data.length; i += 4) {
                if (data[i + 3] === 0)
                    continue;
                const l = (0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2]) / 255;
                bins[Math.min(63, Math.floor(l * 64))]++;
                total++;
            }
            // A read that lands before the picture is drawable comes back empty.
            if (total === 0) {
                if (probe.attempts++ < 10)
                    retry.restart();
                return;
            }
            let run = 0;
            let low = 0;
            let high = 1;
            let found = false;
            for (let b = 0; b < 64; b++) {
                run += bins[b];
                if (!found && run > total * 0.02) {
                    low = b / 64;
                    found = true;
                }
                if (run > total * 0.98) {
                    high = (b + 1) / 64;
                    break;
                }
            }
            root.lo = low;
            root.hi = high;
        }
    }

    Timer {
        id: retry

        interval: 150
        onTriggered: probe.requestPaint()
    }

    // Reaches the picture's own loader.
    onSourceChanged: picture.source = root.source
}
