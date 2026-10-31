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
     * Drawn by DotImage, as the rest of the shell's pictures are, with dots
     * fine enough to read as a photo. A masked MultiEffect looked cleaner but
     * took the shell down on the session lock surface, which is the one place
     * a crash locks you out. Framing on a detected subject is off: it is what
     * pushed the face off the centre of its ring.
     */
    DotImage {
        id: photo

        anchors.fill: parent
        anchors.margins: root.inset
        visible: Account.avatar.length > 0
        source: Account.avatar.length > 0 ? `file://${Account.avatar}` : ""
        circular: true
        colored: true
        halftone: false
        frameSubject: false
        dotScale: 0.5
        cell: Math.max(1.4, (root.size - 2 * root.inset) / 90)
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
