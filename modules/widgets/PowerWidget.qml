import QtQuick
import qs.services

// What the machine is drawing, in watts, as a ring.
RingWidget {
    id: root

    property var item: ({})
    property bool live: true

    Watch {
        service: Watts
        live: root.live
    }

    value: Watts.fraction
    // The number is the wattage itself, not a percentage of anything.
    number: Watts.available ? Watts.total : -1
    suffix: "W"
    caption: Watts.available ? (Watts.label.length > 0 ? `power · ${Watts.label}` : "power") : "power · n/a"
}
