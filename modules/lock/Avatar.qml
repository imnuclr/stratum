import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The user's picture: a clean round photo inside a ring of dots.
 *
 * It used to be dithered into dots and framed on a detected subject, which
 * moved the face off the centre of its own ring. The photo is now cropped from
 * its middle and masked to a circle, so it sits exactly in the ring. With no
 * picture, the initial takes its place.
 *
 * `fill` runs the ring's accent from 0 to 1: the unlock fills it.
 */
Item {
    id: root

    property real size: 120
    property real fill: 0
    readonly property real inset: root.size * 0.11

    implicitWidth: root.size
    implicitHeight: root.size

    DotRing {
        anchors.fill: parent
        value: 1
        onColor: Theme.fgFaint
    }

    // The accent sweeping round as it lets you in.
    DotRing {
        anchors.fill: parent
        value: root.fill
        onColor: Theme.accent
        offColor: "transparent"
        visible: root.fill > 0
    }

    /*
     * The photo as it is, cropped square from its middle and cut to a circle,
     * so the face sits in the centre of its ring. The dotted version read as
     * off centre and muddier than the picture.
     *
     * Painted on a canvas rather than masked with MultiEffect: the effect took
     * the shell down on the session lock surface, which is the one place a
     * crash locks you out. (destination-in, the usual way to cut a circle on
     * a canvas, is ignored here and left it square.)
     */
    Canvas {
        id: photo

        readonly property string url: Account.avatar.length > 0 ? `file://${Account.avatar}` : ""

        anchors.fill: parent
        anchors.margins: root.inset
        visible: Account.avatar.length > 0

        // The canvas loads the file itself: drawing from an Image item before
        // it was drawable came back empty and left the ring with nothing in it.
        onUrlChanged: if (url.length > 0) loadImage(url)
        Component.onCompleted: if (url.length > 0) loadImage(url)
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!isImageLoaded(url) || width <= 0)
                return;
            const img = ctx.createImageData(url);
            const iw = img.width;
            const ih = img.height;
            const side = Math.min(iw, ih);
            const r = Math.min(width, height) / 2;
            ctx.save();
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
            ctx.clip();
            ctx.drawImage(url, (iw - side) / 2, (ih - side) / 2, side, side, 0, 0, width, height);
            ctx.restore();
            // A clip edge is not smoothed; a thin ring of the background over
            // it is.
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, r - 0.75, 0, Math.PI * 2);
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = Theme.bg;
            ctx.stroke();
        }
    }

    Rectangle {
        anchors.fill: photo
        radius: width / 2
        visible: Account.avatar.length === 0
        color: Theme.surfaceHi

        Text {
            anchors.centerIn: parent
            text: Account.firstName.charAt(0).toUpperCase()
            color: Theme.fgBright
            font.family: Theme.fontRounded
            font.pixelSize: root.size * 0.36
            font.variableAxes: ({ "wght": 500 })
            renderType: Text.NativeRendering
        }
    }
}
