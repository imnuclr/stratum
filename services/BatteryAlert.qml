pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

/*
 * Saying something when the battery is running out.
 *
 * The shell knew the battery was low — the glyph in the bar coloured, and
 * Power.low had been true for some time — but it never said so, which is no use
 * at all on a machine whose bar is a thin column at the side of the screen. The
 * one state worth interrupting for is the one you cannot recover from.
 *
 * Sent through notify-send rather than drawn here, so a warning is an ordinary
 * notification: it toasts like anything else, it lands in the list in the
 * notification centre, and it is dismissed the same way. Writing a bespoke
 * banner would mean a second thing that looks like a notification and behaves
 * like nothing else in the shell.
 *
 * Each level fires once per discharge. Crossing back above a level — plugging
 * in, or the reading drifting up a point — re-arms it, so a battery hovering on
 * the threshold does not warn every time it is polled. Plugging in silences
 * everything at once: the problem is solved and the warning has nothing left to
 * say.
 */
Singleton {
    id: root

    /*
     * The levels, in the order they are met on the way down. `urgent` marks the
     * one the sender flags Critical, which is what makes it survive Do Not
     * Disturb and colour the count in the list.
     */
    readonly property var levels: [
        { key: "low", at: Config.get("power.warnAt", 0.20), urgent: false },
        { key: "veryLow", at: Config.get("power.warnVeryLowAt", 0.10), urgent: true },
        { key: "critical", at: Config.get("power.warnCriticalAt", 0.05), urgent: true }
    ]

    readonly property bool enabled: Config.get("power.warn", true) && Power.hasBattery

    // Levels already announced during this discharge, by key.
    property var fired: ({})

    /*
     * One notification id for all of them, so a warning replaces the one before
     * it rather than stacking three cards saying the same thing more urgently.
     * Fixed rather than taken from the server: the server's ids belong to
     * whatever else is on screen.
     */
    readonly property int tag: 90210

    function markFired(key, on) {
        const next = Object.assign({}, root.fired);
        if (on)
            next[key] = true;
        else
            delete next[key];
        root.fired = next;
    }

    function announce(level) {
        const pct = Math.round(Power.percentage * 100);
        const left = Power.timeToEmpty > 0 ? ` · about ${Power.formatTime(Power.timeToEmpty)} left` : "";
        const body = level.key === "low"
            ? `${pct}% remaining${left}. Worth finding a charger.`
            : level.key === "veryLow"
            ? `${pct}% remaining${left}. Plug in soon.`
            : `${pct}% remaining${left}. The machine will suspend shortly.`;
        send.command = [
            "notify-send",
            "--app-name=Battery",
            /*
             * The freedesktop status names. Whether they resolve depends on the
             * icon theme Qt has been given, which under a bare Wayland session
             * is often only hicolor — and hicolor carries no battery icons at
             * all. The notification then falls back to a letter in a ring, as
             * any sender without an icon does, which is tidy enough that it is
             * not worth shipping a picture of a battery to avoid.
             */
            `--icon=${pct <= 10 ? "battery-caution" : "battery-low"}`,
            `--urgency=${level.urgent ? "critical" : "normal"}`,
            `--replace-id=${root.tag}`,
            // Critical warnings stay until acknowledged; the first is a nudge
            // and times out like any other notification.
            `--expire-time=${level.urgent ? 0 : 10000}`,
            "--hint=string:category:battery",
            level.key === "critical" ? "Battery critical" : "Battery low",
            body
        ];
        send.running = true;
        Diag.log("battery", `warned at ${pct}% (${level.key})`);
    }

    /*
     * Deliberately driven by a change in the reading rather than by a binding
     * per level: the levels have to be considered in order so that a machine
     * woken at 4% warns once, as critical, instead of firing all three.
     */
    function check() {
        if (!root.enabled)
            return;

        // On the charger: nothing to warn about, and everything re-arms for the
        // next time it comes off.
        if (!Power.onBattery || Power.charging) {
            if (Object.keys(root.fired).length > 0)
                root.fired = ({});
            return;
        }

        const pct = Power.percentage;
        // A battery that has not reported yet reads 0, which is not the same as
        // empty and must not be warned about.
        if (!(pct > 0))
            return;

        let worst = null;
        for (const level of root.levels) {
            if (pct > level.at) {
                // Risen back above it: armed again.
                root.markFired(level.key, false);
                continue;
            }
            worst = level;
        }

        if (!worst || root.fired[worst.key])
            return;

        root.markFired(worst.key, true);
        // Everything above the one being announced counts as said: crossing
        // 20% and 10% between two polls is one event, not two.
        for (const level of root.levels) {
            if (level.at > worst.at)
                root.markFired(level.key, true);
        }
        root.announce(worst);
    }

    onEnabledChanged: root.check()

    Connections {
        target: Power

        function onPercentageChanged() {
            root.check();
        }

        function onOnBatteryChanged() {
            root.check();
        }

        function onChargingChanged() {
            root.check();
        }
    }

    /*
     * A backstop for the case the reading does not change often enough to carry
     * the check — a battery sitting on 19% for ten minutes still has to warn
     * once, and does, but only the first time.
     */
    Timer {
        running: root.enabled
        repeat: true
        interval: 60000
        onTriggered: root.check()
    }

    Process {
        id: send
    }
}
