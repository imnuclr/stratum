import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * How long since this machine was last started, in the largest two units that
 * say something: "3d 14h", "14h 06m", "6m".
 */
Item {
    id: root

    property var item: ({})
    property bool live: true

    readonly property real pad: Math.min(width, height) * 0.12

    Column {
        anchors.left: parent.left
        anchors.leftMargin: root.pad
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.height * 0.06)

        DotText {
            text: Uptime.brief
            size: Math.max(14, Math.min(root.height * 0.42, (root.width - root.pad * 2) / Math.max(5, Uptime.brief.length) * 1.7))
            plain: true
        }

        SectionLabel {
            text: "up"
            color: Theme.fgDim
        }
    }
}
