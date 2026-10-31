import QtQuick
import qs.theme

/*
 * Power profile as a run of ascending bars, filled to the active level.
 *
 * A bolt said only "power" and nothing about which profile was set, which is the
 * one thing the indicator exists to report. One bar per profile the system
 * actually offers, rather than a fixed four, so the glyph cannot imply a mode
 * that does not exist here.
 */
Item {
    id: root

    property int level: 1
    /*
     * Always four bars, whatever the machine offers. The glyph is a scale, and a
     * scale that changes length between machines is not one — the active level is
     * mapped onto the four rather than the bars being counted out.
     */
    property int count: 4
    property real size: 17
    property color color: Theme.fg
    property color dimColor: Qt.alpha(Theme.fgFaint, 0.5)

    implicitWidth: size
    implicitHeight: size

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Math.max(1, root.size * 0.09)

        Repeater {
            model: root.count

            Rectangle {
                required property int index

                // Shortest bar still tall enough to read as a bar rather than a
                // dot, growing to the full height at the top of the range.
                readonly property real fraction: (index + 1) / root.count

                width: Math.max(2, root.size * 0.17)
                height: root.size * (0.35 + 0.6 * fraction)
                radius: width / 2
                color: index < root.level ? root.color : root.dimColor

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }
            }
        }
    }
}
