import QtQuick
import qs.components
import qs.services
import qs.theme
import qs.utils

/*
 * Rounded battery whose fill tracks charge, plus a dot-matrix percentage that
 * only appears once it matters.
 */
Row {
    id: root

    spacing: Theme.space(1)

    BatteryGlyph {
        anchors.verticalCenter: parent.verticalCenter
        size: 24
        level: Power.percentage
        charging: Power.charging
        color: root.barColour
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
