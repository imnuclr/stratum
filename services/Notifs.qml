pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.services

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

    /*
     * Two views of the same thing. `list` is a plain array, for counting and for
     * walking; `model` is the server's own object model, which is what a view has
     * to be given.
     *
     * Handing a view the array instead looks like it works and quietly destroys
     * every animation: a new array is a whole new model, so the view resets
     * rather than being told one row went, and a reset destroys and rebuilds
     * every delegate. No add or remove transition can run across one — the rows
     * simply blink from one arrangement to the next.
     */
    readonly property var list: server.trackedNotifications?.values ?? []
    readonly property var model: server.trackedNotifications
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

    // Dismissing one. The row's close button called this before it existed, so
    // clearing a single notification quietly did nothing at all.
    function dismiss(notification) {
        notification?.dismiss();
    }

    function clearAll() {
        // Dismissing mutates the list being walked, so copy first.
        for (const n of [...root.list])
            n.dismiss();
    }

    /*
     * What clicking a notification does. The sender's default action if it
     * offered one — that is the action a desktop environment invokes when the
     * body is clicked — and otherwise bring the application's own window forward,
     * which is what someone reaching for the notification wanted either way.
     */
    function activate(notification) {
        if (!notification)
            return;

        const actions = notification.actions ?? [];
        const fallback = actions.length === 1 ? actions[0] : null;
        const preferred = actions.find(a => a.identifier === "default") ?? fallback;
        if (preferred) {
            preferred.invoke();
            return;
        }

        Hypr.focusApp(notification.desktopEntry || notification.appName);
    }

    /*
     * Whether a notification is new enough to still be worth announcing.
     *
     * Toast delegates are built for every tracked notification, including ones
     * that were already on screen before the delegate existed — after a config
     * reload, say. Without this they would all announce themselves again at once.
     * Deliberately not a binding: it answers for the moment it is asked.
     */
    function fresh(notification, within) {
        const at = root.arrivals[notification?.id];
        return at !== undefined && Date.now() - at < within;
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
