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
     * Urgency, which the shell had been throwing away. The spec gives a sender
     * three levels and almost all of them mean Normal; Critical is the one that
     * earns the accent, because it is the only notification the sender is saying
     * should not be missed, and that is exactly the bar the design sets for
     * colour appearing at all.
     *
     * Low is worth keeping too, in the other direction: a battery-level or
     * now-playing ping should sit back rather than shout.
     */
    /*
     * What stands for a notification, as a path the UI can show.
     *
     * A picture the sender attached comes first — a chat app sends the person's
     * profile picture that way, and who a message is from matters more than
     * which app carried it. Otherwise the application's icon, wherever it can be
     * found: what the notification names, a file it points at, the icon of its
     * desktop entry, or an icon named after the app.
     *
     * `appOnly` skips the attached picture, for the places that are labelling
     * the application rather than the message — a group header wants the app's
     * own mark, not whichever face happened to send the newest message.
     */
    function iconFor(notification, appOnly) {
        const n = notification;
        if (!n)
            return "";
        if (!appOnly) {
            const picture = n.image ?? "";
            if (picture.length > 0)
                return picture.startsWith("/") ? `file://${picture}` : picture;
        }
        const named = n.appIcon ?? "";
        if (named.startsWith("/"))
            return `file://${named}`;
        if (named.startsWith("file://") || named.startsWith("image://"))
            return named;
        const tries = [named];
        const entry = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null;
        if (entry?.icon)
            tries.push(entry.icon);
        if (n.desktopEntry)
            tries.push(n.desktopEntry);
        if (n.appName)
            tries.push(n.appName.toLowerCase(), n.appName.toLowerCase().replace(/\s+/g, "-"));
        for (const t of tries) {
            if (!t)
                continue;
            const p = Quickshell.iconPath(t, true);
            if (p && p.length > 0)
                return p;
        }
        return "";
    }

    function isCritical(notification) {
        return notification?.urgency === NotificationUrgency.Critical;
    }

    function isLow(notification) {
        return notification?.urgency === NotificationUrgency.Low;
    }

    readonly property int criticalCount: list.filter(n => n?.urgency === NotificationUrgency.Critical).length
    readonly property bool anyCritical: criticalCount > 0

    /*
     * The list folded by app.
     *
     * Ten pings from one chat are one thing that happened, not ten, and a flat
     * list of them buries everything else under whichever app is noisiest. Each
     * group keeps its own notifications in arrival order and the groups
     * themselves sit newest-first, so the app that just spoke is at the top
     * however long its backlog is.
     *
     * Plain JS objects rather than the server's model: the model cannot express
     * a grouping, and a view over it could only ever show the flat list.
     */
    readonly property var groups: {
        const by = {};
        const order = [];
        for (const n of root.list) {
            const key = n?.appName || "system";
            if (!by[key]) {
                by[key] = { app: key, items: [], newest: null };
                order.push(key);
            }
            by[key].items.push(n);
            by[key].newest = n;
        }
        // Newest group first, by the most recent arrival each one holds.
        return order.map(k => by[k]).reverse();
    }

    /*
     * Do not disturb. Notifications are still accepted and still listed — the
     * flag suppresses the interruption, not the record, so nothing is lost while
     * it is on.
     *
     * Any focus mode counts, so the bell in the bar and everything else that
     * reads this show quiet whichever one is on; toggling it turns Do Not
     * Disturb on, or whatever mode is on off.
     */
    readonly property bool dnd: Focus.on

    function toggleDnd() {
        if (Focus.on)
            Focus.stop();
        else
            Focus.set("dnd", "off");
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
     * body is clicked — and then brings the application's own window to the
     * workspace in front of you, which is what someone reaching for the
     * notification wanted either way.
     */
    function activate(notification) {
        if (!notification)
            return;

        const actions = notification.actions ?? [];
        const fallback = actions.length === 1 ? actions[0] : null;
        const preferred = actions.find(a => a.identifier === "default") ?? fallback;
        const app = notification.desktopEntry || notification.appName;
        if (preferred)
            preferred.invoke();
        // Either way the window is brought here as an ordinary one: the app's
        // own activation shows it wherever a window rule left it, which for a
        // chat app is a scratchpad.
        Apps.open(app, false);
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
