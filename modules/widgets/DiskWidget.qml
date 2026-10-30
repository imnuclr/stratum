import QtQuick
import qs.services

// How full the system disk is, as a ring.
RingWidget {
    id: root

    property var item: ({})
    property bool live: true

    Watch {
        service: Disk
        live: root.live
    }

    value: Disk.used
    number: Disk.available ? Disk.used * 100 : -1
    suffix: "%"
    caption: "disk"
}
