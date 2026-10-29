import QtQuick
import qs.theme

/*
 * Wifi strength drawn as stacked arcs, all four always present and the unlit
 * ones dimmed.
 *
 * Swapping between four separate glyphs loses the shape entirely at low signal —
 * the weakest variant is a single dot, which reads as "no icon" rather than
 * "weak signal".
 */
Item {
    id: root

    // 0..100
    property int strength: 0
    property real size: 16
    property color color: Theme.fgDim
    property color dimColor: Qt.alpha(Theme.fgFaint, 0.45)

    readonly property int bars: {
        if (strength >= 70)
            return 3;
        if (strength >= 45)
            return 2;
        if (strength >= 20)
            return 1;
        return 0;
    }

    implicitWidth: size
    implicitHeight: size

    Repeater {
        model: ["wifi-dot", "wifi-arc1", "wifi-arc2", "wifi-arc3"]

        Glyph {
            required property int index
            required property string modelData

            anchors.fill: parent
            name: modelData
            size: root.size
            // The dot is always lit: the radio is on, there just isn't much signal.
            color: index === 0 || index <= root.bars ? root.color : root.dimColor
        }
    }
}
