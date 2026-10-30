import QtQuick
import QtQuick.Shapes
import qs.theme

/*
 * A rounded battery whose fill is the charge.
 *
 * The fill is inset by the same amount on every side, so it sits centred inside
 * the outline and, at 100%, reads as the cell being full rather than as a bar
 * floating off to one side. Its corners follow the outline's, a step tighter.
 * Drawn rather than swapped between level glyphs so the charge moves
 * continuously instead of in four steps.
 */
Item {
    id: root

    property real level: 0
    property bool charging: false
    property bool vertical: false
    // The long edge, nub included.
    property real size: 24
    property color color: Theme.fg

    readonly property real thick: size * 0.56
    readonly property real nub: Math.max(2, size * 0.09)
    readonly property real stroke: Math.max(1.3, size * 0.07)
    readonly property real inset: stroke + Math.max(1, size * 0.05)
    readonly property real bodyLength: size - nub - 1
    readonly property real bodyRadius: thick * 0.32
    readonly property real innerLength: bodyLength - inset * 2
    readonly property real innerThick: thick - inset * 2
    // Never thinner than a pill's own height, or a nearly empty cell would
    // draw a sliver with square-looking ends.
    readonly property real fillLength: root.level <= 0
        ? 0
        : Math.max(root.innerThick, root.innerLength * Math.min(1, root.level))

    implicitWidth: vertical ? thick : size
    implicitHeight: vertical ? size : thick

    // Everything is laid out horizontally and turned for the vertical form.
    // Counter-rotated so the bolt stays upright.
    Item {
        anchors.centerIn: parent
        width: root.size
        height: root.thick
        rotation: root.vertical ? -90 : 0

        Rectangle {
            id: body

            width: root.bodyLength
            height: root.thick
            radius: root.bodyRadius
            color: "transparent"
            border.width: root.stroke
            border.color: root.color
        }

        Rectangle {
            anchors.left: body.right
            anchors.leftMargin: 1
            anchors.verticalCenter: body.verticalCenter
            width: root.nub
            height: root.thick * 0.4
            radius: width / 2
            color: root.color
        }

        Rectangle {
            x: root.inset
            y: root.inset
            width: root.fillLength
            height: root.innerThick
            radius: Math.max(1, root.bodyRadius - root.inset * 0.6)
            color: root.color
            visible: root.level > 0

            Behavior on width {
                NumberAnimation {
                    duration: Theme.standard
                }
            }
        }

        // A bolt through the cell. Dark where it crosses the fill, light where
        // it crosses the empty part, so it reads at either end of the charge.
        Shape {
            id: bolt

            anchors.centerIn: body
            visible: root.charging
            rotation: root.vertical ? 90 : 0
            width: root.thick * 0.55
            height: root.thick * 0.8

            ShapePath {
                strokeWidth: 0
                fillColor: root.level > 0.5 ? Theme.bg : root.color
                // Points scaled to this item, so the bolt grows with the cell.
                startX: bolt.width * 0.62
                startY: 0
                PathLine { x: bolt.width * 0.1; y: bolt.height * 0.58 }
                PathLine { x: bolt.width * 0.48; y: bolt.height * 0.58 }
                PathLine { x: bolt.width * 0.38; y: bolt.height }
                PathLine { x: bolt.width * 0.92; y: bolt.height * 0.4 }
                PathLine { x: bolt.width * 0.54; y: bolt.height * 0.4 }
                PathLine { x: bolt.width * 0.62; y: 0 }
            }
        }
    }
}
