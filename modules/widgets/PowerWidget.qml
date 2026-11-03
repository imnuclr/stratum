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

    // Plugged in, a laptop's battery says only what is going into it, so that
    // is shown, and said to be, rather than nothing.
    readonly property bool charging: !Watts.available && Watts.charging > 0

    value: root.charging ? Math.min(1, Watts.charging / Watts.ceiling) : Watts.fraction
    // The number is the wattage itself, not a percentage of anything.
    number: Watts.available ? Watts.total : (root.charging ? Watts.charging : -1)
    suffix: "W"
    caption: Watts.available ? (Watts.label.length > 0 ? `power · ${Watts.label}` : "power")
        : (root.charging ? "power · charging" : "power · n/a")
}
