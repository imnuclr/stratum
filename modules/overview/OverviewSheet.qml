import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Every workspace at once, reached from the top-left corner.
 *
 * Laid out as a single row rather than a grid: workspaces are an ordered list and
 * a grid implies a second axis that does not exist.
 */
Sheet {
    id: root

    name: "overview"
    originX: 0
    originY: 0
    hoverDismiss: true

    readonly property int count: Config.get("bar.workspaces.count", 6)
    readonly property real card: Config.get("overview.cardWidth", 260)

    sheetWidth: Math.min(monitor.width - Theme.space(8),
        root.count * card + (root.count - 1) * Theme.space(3) + Theme.space(4) * 2)
    sheetHeight: body.implicitHeight + Theme.space(4) * 2

    Column {
        id: body

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.space(4)
        spacing: Theme.space(3)

        SectionLabel {
            text: "overview"
        }

        Row {
            spacing: Theme.space(3)

            Repeater {
                model: root.count

                WorkspaceCard {
                    required property int index

                    wsId: index + 1
                    cardWidth: root.card
                    monitor: root.monitor
                }
            }
        }
    }
}
