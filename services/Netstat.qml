pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

/*
 * Network throughput for the active interface.
 *
 * /sys/.../statistics/{rx,tx}_bytes are cumulative counters, so rate comes from
 * the difference between two samples divided by the interval. Counters also
 * reset when an interface goes down, which would otherwise show as a enormous
 * negative spike, so a decrease is treated as a re-baseline rather than a rate.
 */
Singleton {
    id: root

    readonly property string iface: Network.active?.name ?? ""

    property real rxRate: 0
    property real txRate: 0

    property real lastRx: 0
    property real lastTx: 0
    property real lastAt: 0

    // Peak seen in this session, used to scale the dashboard's meters — a fixed
    // ceiling is either always empty on a slow link or always full on a fast one.
    property real peak: 262144

    readonly property real rxScaled: peak > 0 ? Math.min(1, rxRate / peak) : 0
    readonly property real txScaled: peak > 0 ? Math.min(1, txRate / peak) : 0

    readonly property int historyLength: 22
    property var rxHistory: new Array(22).fill(0)
    property var txHistory: new Array(22).fill(0)

    property int watchers: 0

    function watch() {
        root.watchers++;
    }

    function unwatch() {
        root.watchers = Math.max(0, root.watchers - 1);
    }

    // Widgets on an energy saver: kept running, at the slow tick.
    property int slowWatchers: 0

    function watchSlowly() {
        root.slowWatchers++;
    }

    function unwatchSlowly() {
        root.slowWatchers = Math.max(0, root.slowWatchers - 1);
    }

    /*
     * Split rather than one string: the strip renders the number in dot numerals
     * and the unit as a caps label, which cannot be done to one piece of text.
     */
    function humanNumber(bytesPerSecond) {
        let v = bytesPerSecond;
        let i = 0;
        while (v >= 1024 && i < 3) {
            v /= 1024;
            i++;
        }
        return v < 10 && i > 0 ? v.toFixed(1) : `${Math.round(v)}`;
    }

    function humanUnit(bytesPerSecond) {
        const units = ["B/S", "KB/S", "MB/S", "GB/S"];
        let v = bytesPerSecond;
        let i = 0;
        while (v >= 1024 && i < 3) {
            v /= 1024;
            i++;
        }
        return units[i];
    }

    function human(bytesPerSecond) {
        const units = ["B", "K", "M", "G"];
        let v = bytesPerSecond;
        let i = 0;
        while (v >= 1024 && i < units.length - 1) {
            v /= 1024;
            i++;
        }
        return `${v < 10 && i > 0 ? v.toFixed(1) : Math.round(v)}${units[i]}`;
    }

    function sample() {
        if (!iface)
            return;
        rxFile.path = `/sys/class/net/${iface}/statistics/rx_bytes`;
        txFile.path = `/sys/class/net/${iface}/statistics/tx_bytes`;
        rxFile.reload();
        txFile.reload();
    }

    // Both counters are read before either rate is computed, so they share one
    // interval; updating on each file's own load would halve one of the rates.
    function commit(rx, tx) {
        const now = Date.now();
        const dt = (now - root.lastAt) / 1000;

        if (root.lastAt > 0 && dt > 0 && rx >= root.lastRx && tx >= root.lastTx) {
            root.rxRate = (rx - root.lastRx) / dt;
            root.txRate = (tx - root.lastTx) / dt;
            root.peak = Math.max(root.peak, root.rxRate, root.txRate);
            root.rxHistory = [...root.rxHistory, root.rxScaled].slice(-root.historyLength);
            root.txHistory = [...root.txHistory, root.txScaled].slice(-root.historyLength);
        }

        root.lastRx = rx;
        root.lastTx = tx;
        root.lastAt = now;
    }

    property real pendingRx: -1
    property real pendingTx: -1

    onIfaceChanged: {
        root.lastAt = 0;
        root.rxRate = 0;
        root.txRate = 0;
    }

    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: root.watchers > 0 ? 1000 : 5000
        onTriggered: root.sample()
    }

    FileView {
        id: rxFile

        onLoaded: {
            root.pendingRx = parseInt(text());
            if (root.pendingTx >= 0) {
                root.commit(root.pendingRx, root.pendingTx);
                root.pendingRx = -1;
                root.pendingTx = -1;
            }
        }
    }

    FileView {
        id: txFile

        onLoaded: {
            root.pendingTx = parseInt(text());
            if (root.pendingRx >= 0) {
                root.commit(root.pendingRx, root.pendingTx);
                root.pendingRx = -1;
                root.pendingTx = -1;
            }
        }
    }
}
