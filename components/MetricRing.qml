import QtQuick
import qs.theme

/*
 * A reading as a dotted ring: the ring for the level, a number in the middle,
 * a caption underneath.
 *
 * Both move rather than jump. The ring sweeps through the dots in between, and
 * the number counts its way to the new value, so a reading that is polled every
 * second or two changes in a way the eye can follow.
 */
Item {
    id: root

    // 0 to 1, for the ring.
    property real value: 0
    // What the middle says; below zero means there is nothing to say.
    property real number: -1
    property string suffix: ""
    property string caption: ""
    property real size: 92
    property real numberSize: root.size * 0.25

    property real shownNumber: Math.max(0, root.number)

    Behavior on shownNumber {
        NumberAnimation {
            duration: Theme.sheetMs * 1.4
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft
        }
    }

    implicitWidth: root.size
    implicitHeight: root.size + (root.caption.length > 0 ? label.implicitHeight + Theme.space(2) : 0)

    DotRing {
        id: ring

        width: root.size
        height: root.size
        value: root.value

        DotText {
            anchors.centerIn: parent
            text: root.number < 0 ? "--" : `${Math.round(root.shownNumber)}${root.suffix}`
            size: root.numberSize
            plain: true
        }
    }

    SectionLabel {
        id: label

        anchors.top: ring.bottom
        anchors.topMargin: Theme.space(2)
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.caption.length > 0
        text: root.caption
        color: Theme.fgDim
    }
}
