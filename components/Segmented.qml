pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

/*
 * A row of exclusive choices. The chosen one is inverted — the same fill the rest
 * of the shell uses for "on" — so state reads without a second indicator.
 *
 * Takes plain strings and reports an index, and does not own the selection:
 * `current` is bound by whoever knows the truth, and a click only asks.
 */
Row {
    id: root

    property var model: []
    property int current: 0

    signal picked(int index)

    spacing: Theme.space(1)

    Repeater {
        model: root.model

        Rectangle {
            id: seg

            required property int index
            required property var modelData

            readonly property bool chosen: seg.index === root.current

            implicitWidth: label.implicitWidth + Theme.space(4) * 2
            height: 34
            radius: height / 2
            color: seg.chosen ? Theme.fg : (hover.hovered ? Theme.surfaceTop : Theme.surfaceHi)

            Behavior on color {
                ColorAnimation {
                    duration: Theme.micro
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

            Text {
                id: label

                anchors.centerIn: parent
                text: seg.modelData
                color: seg.chosen ? Theme.bg : Theme.fgBright
                font.family: Theme.fontUi
                font.pixelSize: 10
                font.weight: Font.Medium
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.2
                renderType: Text.NativeRendering

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.picked(seg.index)
            }
        }
    }
}
