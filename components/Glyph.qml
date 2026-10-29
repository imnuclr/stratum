import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.utils

/*
 * Stroke icon. Paths are authored on a 24x24 grid and scaled from the top-left,
 * so `stroke` stays in grid units and thins consistently as `size` drops.
 */
Item {
    id: root

    property string name: ""
    property real size: 17
    property color color: Theme.fg
    property real stroke: 1.7

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        preferredRendererType: Shape.CurveRenderer
        transformOrigin: Item.TopLeft
        scale: root.size / 24

        ShapePath {
            id: shapePath

            strokeColor: root.color
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: Icons.path(root.name)
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.micro
        }
    }
}
