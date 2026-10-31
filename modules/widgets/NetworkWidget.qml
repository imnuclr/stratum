import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * What the network is carrying right now, down and up, and what it is.
 */
Item {
    id: root

    property var item: ({})
    property bool live: true

    Watch {
        service: Netstat
        live: root.live
    }

    function rate(bytes) {
        if (bytes >= 1048576)
            return { n: (bytes / 1048576).toFixed(bytes >= 10485760 ? 0 : 1), u: "MB/s" };
        if (bytes >= 1024)
            return { n: Math.round(bytes / 1024), u: "KB/s" };
        return { n: Math.round(bytes), u: "B/s" };
    }

    readonly property real figure: Math.max(20, Math.min(root.height * 0.3, root.width * 0.12))

    SectionLabel {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.space(5)
        text: Network.connected ? Network.label : "offline"
        color: Theme.fgDim
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.space(5)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space(5)
        spacing: Theme.space(7)

        Repeater {
            model: [
                { label: "down", value: Netstat.rxRate },
                { label: "up", value: Netstat.txRate }
            ]

            Column {
                id: col

                required property var modelData

                readonly property var r: root.rate(col.modelData.value)

                spacing: Theme.space(1)

                SectionLabel {
                    text: `${col.modelData.label} · ${col.r.u}`
                    color: Theme.fgDim
                }

                DotText {
                    text: `${col.r.n}`
                    size: root.figure
                    plain: true
                }
            }
        }
    }
}
