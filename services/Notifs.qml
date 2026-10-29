pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

/*
 * The notification server, and the list the shell shows.
 *
 * A notification is not kept unless it is claimed: the server hands it over on
 * the `notification` signal and drops it again the moment that returns, so
 * `tracked` has to be set there or the list stays empty.
 *
 * Arrival time is recorded here because Notification does not carry one. The
 * list shows an age rather than a clock time — how long ago something arrived is
 * what matters, and the exact minute almost never is.
 *
 * `keepOnReload` is false deliberately: a notification held across a config
 * reload outlives the window that was showing it, and the sender has long since
 * stopped caring.
 */
Singleton {
    id: root

    readonly property var list: server.trackedNotifications?.values ?? []
    readonly property int count: list.length
    readonly property bool any: count > 0

    /*
     * Do not disturb. Notifications are still accepted and still listed — the
     * flag suppresses the interruption, not the record, so nothing is lost while
     * it is on.
     */
    property bool dnd: false

    function toggleDnd() {
        root.dnd = !root.dnd;
    }

    // id -> epoch ms. Pruned on close rather than swept, so it cannot grow.
    property var arrivals: ({})

    // Ticks so the ages on screen advance while a panel is open.
    property int watchers: 0
    property int clock: 0

    function watch() {
        root.watchers++;
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
    }

    function clearAll() {
        // Dismissing mutates the list being walked, so copy first.
        for (const n of [...root.list])
            n.dismiss();
    }

    function age(notification) {
        // Touch the tick so this re-evaluates as it advances.
        void root.clock;

        const at = root.arrivals[notification?.id];
        if (at === undefined)
            return "now";

        const seconds = Math.max(0, (Date.now() - at) / 1000);
        if (seconds < 60)
            return "now";
        const minutes = Math.floor(seconds / 60);
        if (minutes < 60)
            return `${minutes} min`;
        const hours = Math.floor(minutes / 60);
        if (hours < 24)
            return `${hours} hr`;
        return `${Math.floor(hours / 24)} d`;
    }

    Timer {
        running: root.watchers > 0
        repeat: true
        interval: 30000
        onTriggered: root.clock++
    }

    NotificationServer {
        id: server

        keepOnReload: false
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;

            const next = root.arrivals;
            next[notification.id] = Date.now();
            root.arrivals = next;

            notification.closed.connect(() => {
                const pruned = root.arrivals;
                delete pruned[notification.id];
                root.arrivals = pruned;
            });
        }
    }
}
