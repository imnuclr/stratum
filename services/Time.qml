pragma Singleton

import QtQuick
import Quickshell
import qs.config

/*
 * One clock for the whole shell. Ticks per minute by default; a consumer that
 * needs seconds calls `useSeconds()` and releases it on destruction, so the
 * shell isn't repainting every second for a panel nobody has open.
 */
Singleton {
    id: root

    property date now: new Date()
    property int secondConsumers: 0

    // Hours and minutes as you like them read: Settings → Appearance → Clock.
    readonly property bool twelveHour: Config.get("clock.twelveHour", false)
    readonly property string hm: root.twelveHour ? "h:mm" : "HH:mm"

    readonly property int hours: now.getHours()
    readonly property int minutes: now.getMinutes()

    function useSeconds() {
        secondConsumers++;
    }

    function releaseSeconds() {
        secondConsumers = Math.max(0, secondConsumers - 1);
    }

    function format(pattern) {
        return Qt.formatDateTime(now, pattern);
    }

    // ISO-8601 week number, which the dashboard shows beside the date.
    function weekNumber() {
        const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
        d.setUTCDate(d.getUTCDate() + 4 - (d.getUTCDay() || 7));
        const start = Date.UTC(d.getUTCFullYear(), 0, 1);
        return Math.ceil(((d - start) / 86400000 + 1) / 7);
    }

    // Fraction of the day elapsed, for the dashboard's day-progress DotBar.
    readonly property real dayProgress: (hours * 60 + minutes) / 1440

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        // Align to the minute boundary when nobody needs seconds.
        interval: root.secondConsumers > 0 ? 1000 : 1000 * (60 - new Date().getSeconds())
        onTriggered: root.now = new Date()
    }
}
