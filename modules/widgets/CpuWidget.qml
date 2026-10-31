import QtQuick
import qs.services

// Processor load as a ring, with its temperature.
RingWidget {
    id: root

    property var item: ({})
    property bool live: true

    Watch {
        service: SysStats
        live: root.live
    }

    value: SysStats.cpu
    number: SysStats.cpu * 100
    caption: SysStats.temperature > 0 ? `cpu · ${Math.round(SysStats.temperature)}°` : "cpu"
}
