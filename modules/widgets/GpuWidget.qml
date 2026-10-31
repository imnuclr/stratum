import QtQuick
import qs.services

// GPU load as a ring, with its temperature where the driver reports one.
RingWidget {
    id: root

    property var item: ({})
    property bool live: true

    Watch {
        service: Gpu
        live: root.live
    }

    value: Gpu.usage
    number: Gpu.available ? Gpu.usage * 100 : -1
    caption: Gpu.available ? (Gpu.temperature > 0 ? `gpu · ${Math.round(Gpu.temperature)}°` : "gpu") : "gpu · n/a"
}
