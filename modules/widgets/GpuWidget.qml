import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * GPU load as a dotted ring, the figure in the middle and its temperature under.
 */
Item {
    id: root

    Component.onCompleted: Gpu.watch()
    Component.onDestruction: Gpu.unwatch()

    DotRing {
        anchors.fill: parent
        anchors.margins: Theme.space(2)
        count: 56
        dotSize: Math.max(2.4, width / 36)
        value: Gpu.usage
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.space(2)

        DotText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Gpu.available ? `${Math.round(Gpu.usage * 100)}` : "--"
            size: Math.min(root.width, root.height) * 0.27
            plain: true
        }

        SectionLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Gpu.available ? (Gpu.temperature > 0 ? `gpu · ${Math.round(Gpu.temperature)}°` : "gpu") : "gpu · n/a"
            color: Theme.fgDim
        }
    }
}
