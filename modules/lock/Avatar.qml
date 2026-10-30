import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The user's picture, ordered-dithered into dots and set inside a ring of dots.
 * With no picture, their initial takes its place so the ring is never empty.
 */
Item {
    id: root

    property real size: 120
    // Gap between the ring and the picture.
    readonly property real inset: root.size * 0.13

    implicitWidth: root.size
    implicitHeight: root.size

    DotRing {
        anchors.fill: parent
        value: 1
        count: 48
        dotSize: Math.max(2.4, root.size * 0.03)
        onColor: Theme.fg
    }

    DotImage {
        anchors.fill: parent
        anchors.margins: root.inset
        visible: Account.avatar.length > 0
        source: Account.avatar.length > 0 ? `file://${Account.avatar}` : ""
        circular: true
        halftone: true
        colored: true
        frameSubject: true
        dotScale: 0.5
        // Fine enough to read as a face; the dots are what make it the shell's.
        cell: Math.max(1.8, (root.size - 2 * root.inset) / 58)
        dotColor: Theme.fg
    }

    Text {
        anchors.centerIn: parent
        visible: Account.avatar.length === 0
        text: Account.firstName.charAt(0)
        color: Theme.fgBright
        font.family: Theme.fontRounded
        font.pixelSize: root.size * 0.4
        font.variableAxes: ({ "wght": 400 })
        renderType: Text.NativeRendering
    }
}
