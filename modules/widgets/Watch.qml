import QtQuick
import qs.services

/*
 * Keeps a polling service running for a widget only while the widget is in view.
 *
 * Services poll only while something watches them. A widget used to watch from
 * the moment it existed, so with windows over the desktop the shell went on
 * reading processor load and the GPU every second for widgets nobody could see.
 * `live` comes from the canvas, which knows when its desktop is covered.
 *
 * On an energy saver it watches slowly instead — the reading still moves, every
 * few seconds rather than every one — or not at all when widgets are stopped.
 */
QtObject {
    id: root

    required property var service
    property bool live: true

    // "fast", "slow" or "" for not watching; what is held now.
    property string held: ""
    readonly property string wanted: !root.live || Power.saving("widgetsStop") ? ""
        : (Power.saving("widgets") && root.service.watchSlowly ? "slow" : "fast")

    function release() {
        if (root.held === "fast")
            root.service.unwatch();
        else if (root.held === "slow")
            root.service.unwatchSlowly();
        root.held = "";
    }

    function sync() {
        if (root.wanted === root.held)
            return;
        root.release();
        if (root.wanted === "fast")
            root.service.watch();
        else if (root.wanted === "slow")
            root.service.watchSlowly();
        root.held = root.wanted;
    }

    onWantedChanged: root.sync()
    Component.onCompleted: root.sync()
    Component.onDestruction: root.release()
}
