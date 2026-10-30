import QtQuick
import qs.components
import qs.theme

/*
 * A disc-shaped reading: a dotted ring around the edge, a number that counts to
 * its value in the middle, and a caption under the number. The GPU, battery and
 * disk widgets are this with their own reading.
 */
Item {
    id: root

    property real value: 0
    // Below zero shows "--".
    property real number: -1
    property string suffix: ""
    property string caption: ""

    readonly property real unit: Math.min(root.width, root.height)

    property real shownNumber: Math.max(0, root.number)

    Behavior on shownNumber {
        NumberAnimation {
            duration: Theme.sheetMs * 1.4
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft
        }
    }

    DotRing {
        anchors.centerIn: parent
        width: root.unit - root.unit * 0.1
        height: width
        count: 56
        dotSize: Math.max(2.4, width / 36)
        value: root.value
    }

    Column {
        anchors.centerIn: parent
        spacing: root.unit * 0.04

        DotText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.number < 0 ? "--" : `${Math.round(root.shownNumber)}${root.suffix}`
            size: root.unit * 0.24
            plain: true
        }

        SectionLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.caption
            color: Theme.fgDim
        }
    }
}
