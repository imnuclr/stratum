import QtQuick
import qs.services

// Charge as a ring, with what it is doing and how long that will take.
RingWidget {
    id: root

    property var item: ({})
    property bool live: true

    value: Power.hasBattery ? Power.percentage : 0
    number: Power.hasBattery ? Power.percentage * 100 : -1
    caption: {
        if (!Power.hasBattery)
            return "no battery";
        if (Power.full)
            return "full";
        const t = Power.charging ? Power.timeToFull : Power.timeToEmpty;
        if (t <= 0)
            return Power.charging ? "charging" : "battery";
        return Power.charging ? `full in ${Power.formatTime(t)}` : `${Power.formatTime(t)} left`;
    }
}
