import QtQuick
import QtQuick.Effects
import qs.components
import qs.theme

/*
 * One wallpaper layer, drawn in whichever look is chosen: the picture as it is,
 * or dithered into dots. `mono` takes the colour out of either.
 *
 * Both are always loaded from the same source, and only one is shown, so
 * changing the look is a visibility change rather than a reload.
 */
Item {
    id: root

    property url source
    property int pixelWidth: 1920
    property int pixelHeight: 1080
    property string look: "original"
    property bool mono: false
    property real dotSize: 8
    property real dotScale: 0.5
    // 0 to 1: how bright the dots are. Their size is a separate setting.
    property real light: 1

    signal ready

    // Colour taken out of the picture itself. The dots are drawn without colour
    // instead (below), which is cheaper than filtering a canvas.
    layer.enabled: root.mono && root.look === "original"
    layer.effect: MultiEffect {
        saturation: -1
    }

    Image {
        id: picture

        anchors.fill: parent
        visible: root.look === "original"
        fillMode: Image.PreserveAspectCrop
        // Cropped to this monitor rather than scaled to a common size: the
        // 3440x1440 and the 1920x1080 want different parts of the same file.
        sourceSize.width: root.pixelWidth
        sourceSize.height: root.pixelHeight
        asynchronous: true
        cache: false

        onStatusChanged: {
            if (status === Image.Ready && root.look === "original")
                root.ready();
        }
    }

    // The dots take far longer to draw than the picture takes to load, and fading
    // a canvas that has not been drawn yet shows whatever was there before — so for
    // the dotted look the layer is only ready once they are on it.
    Connections {
        target: dots

        function onDrawnChanged() {
            if (dots.drawn && root.look === "dots")
                root.ready();
        }
    }

    DotImage {
        id: dots

        anchors.fill: parent
        visible: root.look === "dots"
        source: root.source.toString()
        cell: root.dotSize
        // Capped below touching: past half a cell the dots overlap and a pale
        // picture turns into a solid sheet with holes.
        dotScale: Math.min(0.5, root.dotScale)
        fit: "crop"
        autoLevels: root.mono
        halftone: true
        colored: !root.mono
        dotAlpha: root.light
    }

    // Reaches the picture's own loader; the dots read the same file themselves.
    onSourceChanged: picture.source = root.source
}
