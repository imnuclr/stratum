import QtQuick
import Quickshell.Widgets
import qs.theme

/*
 * A picture cropped square from its middle and cut to a circle.
 *
 * Its own component because more than one place wants a round photo — a
 * notification's sender, album art, the lyrics view's cover — and each keeping
 * its own copy is how one of them ends up subtly different from the others. The
 * lock screen's avatar still carries its own, deliberately: it is the one
 * surface where a crash locks you out, so it is left alone until there is a
 * reason to touch it.
 *
 * This was a Canvas for a long time, and it was wrong in a way that only showed
 * on some pictures. It drew the file through `loadImage`, which takes a URL and
 * nothing else, so an icon asked for as `image://icon/firefox` came back at
 * whatever size the provider felt like — and then a source rectangle measured in
 * the *requested* size cut a corner out of a bitmap that was actually bigger.
 * That is what the garbled app icons in the notification list were: not blurry
 * logos, quarters of sharp ones. Every attempt to work out the right rectangle
 * runs into the same problem, which is that a scaled Image does not tell you the
 * size of the bitmap behind it.
 *
 * So no arithmetic. An Image in PreserveAspectCrop fills its frame from the
 * middle of the picture — that is the crop, done by the thing that knows the
 * real size — and ClippingRectangle cuts the circle on the GPU. The effect is
 * the same, there is nothing left to get wrong, and it costs no canvas.
 */
ClippingRectangle {
    id: root

    property string source: ""
    // The hairline around the picture, which the clip edge does not draw.
    property color edge: Theme.bg

    readonly property bool hasImage: root.source.length > 0
    // Whether there is something on screen, for a caller that wants to know.
    readonly property bool ready: picture.status === Image.Ready

    radius: Math.min(width, height) / 2
    color: "transparent"
    border.width: root.hasImage ? 1 : 0
    border.color: root.edge

    Image {
        id: picture

        anchors.fill: parent
        visible: root.hasImage
        source: root.source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        /*
         * Decoded at twice the size it is drawn at. Twice rather than exactly,
         * because these frames are small, a scaled display asks for more pixels
         * than the logical size suggests, and an icon theme rounds up to
         * whichever size it actually holds — so asking generously costs a
         * directory, not a resample.
         */
        sourceSize.width: Math.max(32, Math.ceil(Math.max(root.width, root.height) * 2))
        sourceSize.height: Math.max(32, Math.ceil(Math.max(root.width, root.height) * 2))
        mipmap: true
    }
}
