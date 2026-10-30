import QtQuick
import qs.services

// Memory in use as a ring, with how much.
RingWidget {
    id: root

    property var item: ({})
    property bool live: true

    Watch {
        service: SysStats
        live: root.live
    }

    value: SysStats.memory
    number: SysStats.memory * 100
    caption: `mem · ${SysStats.memoryShort}`
}
