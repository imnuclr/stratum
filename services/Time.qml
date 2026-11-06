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

    /*
     * The hour, worked out here rather than by a format pattern. Qt only
     * counts to twelve when the pattern also asks for AM/PM — "h:mm" alone is
     * still 15:41 — which is why the switch appeared to do nothing.
     */
    function hourOf(d, twelve, padded) {
        const h = d.getHours();
        const v = twelve ? (h % 12 || 12) : h;
        return padded || !twelve ? String(v).padStart(2, "0") : String(v);
    }

    function clockOf(d, twelve) {
        return `${root.hourOf(d, twelve, false)}:${String(d.getMinutes()).padStart(2, "0")}`;
    }

    // The time as the bar and panels show it: 3:41 or 15:41.
    readonly property string clock: root.clockOf(root.now, root.twelveHour)
    // Always two digits, for faces drawn digit by digit: 03 or 15.
    readonly property string hour2: root.hourOf(root.now, root.twelveHour, true)

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

    /*
     * Arm the clock for the next boundary.
     *
     * Called again after every tick, not once at start-up: a repeating timer
     * keeps the interval it was given, so a minute timer first armed at :17
     * ticked every 43 seconds for the rest of the session and every minute
     * change landed early. Armed afresh each time, the time changes when the
     * time changes. One-shot rather than repeating, because the interval is the
     * part that has to be recomputed and a one-shot timer can be re-armed
     * without restart semantics entering into it.
     */
    function schedule() {
        const d = new Date();
        ticker.interval = root.secondConsumers > 0
            ? Math.max(50, 1000 - d.getMilliseconds())
            : Math.max(50, 60000 - (d.getSeconds() * 1000 + d.getMilliseconds()));
        // Restart rather than start: asking for seconds in the middle of a
        // minute has to move the tick off the minute boundary, and start() does
        // nothing to a timer that is already armed.
        ticker.restart();
    }

    // Seconds are wanted or no longer wanted: pick up the right cadence at once.
    onSecondConsumersChanged: root.schedule()
    Component.onCompleted: root.schedule()

    Timer {
        id: ticker

        running: false
        repeat: false
        interval: 1000
        onTriggered: {
            root.now = new Date();
            root.schedule();
        }
    }
}
