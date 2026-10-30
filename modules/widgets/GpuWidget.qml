import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * GPU load as a dotted ring, with its temperature underneath.
 */
Item {
    id: root

    Component.onCompleted: Gpu.watch()
    Component.onDestruction: Gpu.unwatch()

    DotRing {
        anchors.centerIn: parent
        width: Math.min(root.width, root.height) - Theme.space(3)
        height: width
        count: 44
        dotSize: Math.max(2.4, width / 24)
        value: Gpu.usage

        DotText {
            anchors.centerIn: parent
            text: Gpu.available ? `${Math.round(Gpu.usage * 100)}` : "--"
            size: Math.max(18, parent.height * 0.3)
            plain: true
        }
    }

    SectionLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space(4)
        text: Gpu.available ? (Gpu.temperature > 0 ? `gpu · ${Math.round(Gpu.temperature)}°` : "gpu") : "gpu · n/a"
        color: Theme.fgBright
    }
}
