import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Processor, memory, graphics and disk as a row of rings, the same rings the
 * deck uses: each sweeps to its new level and counts its number there.
 */
Item {
    id: root

    property var item: ({})
    property bool live: true

    Watch {
        service: SysStats
        live: root.live
    }

    Watch {
        service: Gpu
        live: root.live
    }

    Watch {
        service: Disk
        live: root.live
    }

    // As large as four fit, with room for the captions.
    readonly property real ring: Math.max(48, Math.min((root.height - Theme.space(4) * 2) * 0.72, (root.width - Theme.space(5) * 2) / 4.7))

    Row {
        anchors.centerIn: parent
        spacing: (root.width - Theme.space(5) * 2 - root.ring * 4) / 3

        MetricRing {
            size: root.ring
            value: SysStats.cpu
            number: SysStats.cpu * 100
            caption: SysStats.temperature > 0 ? `cpu · ${Math.round(SysStats.temperature)}°` : "cpu"
        }

        MetricRing {
            size: root.ring
            value: SysStats.memory
            number: SysStats.memory * 100
            caption: `mem · ${SysStats.memoryShort}`
        }

        MetricRing {
            size: root.ring
            value: Gpu.usage
            number: Gpu.available ? Gpu.usage * 100 : -1
            caption: Gpu.available ? (Gpu.temperature > 0 ? `gpu · ${Math.round(Gpu.temperature)}°` : "gpu") : "gpu · n/a"
        }

        MetricRing {
            size: root.ring
            value: Disk.used
            number: Disk.available ? Disk.used * 100 : -1
            caption: "disk"
        }
    }
}
