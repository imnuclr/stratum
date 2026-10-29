import QtQuick
import qs.components
import qs.services
import qs.theme
import qs.utils

/*
 * Battery outline with a fill that tracks charge, plus a dot-matrix percentage
 * that only appears once it matters.
 */
Row {
    id: root

    spacing: Theme.space(1)

    Item {
        anchors.verticalCenter: parent.verticalCenter
        width: 21
        height: 16

        Glyph {
            anchors.fill: parent
            name: Power.charging ? "battery-charging" : ""
            size: 21
            color: barColour
            visible: Power.charging
        }

        // Outline plus fill, drawn rather than swapped between level glyphs, so
        // the charge reads continuously instead of in four steps.
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 17
            height: 9
            radius: 2.5
            color: "transparent"
            border.width: 1.3
            border.color: root.barColour
            visible: !Power.charging

            Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(1, (parent.width - 4) * Power.percentage)
                height: 4
                radius: 1
                color: root.barColour

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.standard
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 2
            height: 4
            radius: 1
            color: root.barColour
            visible: !Power.charging
        }
    }

    readonly property color barColour: {
        if (Power.critical)
            return Theme.crit;
        if (Power.low)
            return Theme.warn;
        return Theme.fgDim;
    }

    // Only shown once the number is actionable — above a quarter it's noise.
    DotText {
        anchors.verticalCenter: parent.verticalCenter
        text: `${Math.round(Power.percentage * 100)}`
        size: 12
        color: root.barColour
        visible: Power.percentage <= 0.25 || Power.charging
    }
}
