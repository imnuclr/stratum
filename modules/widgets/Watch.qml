import QtQuick

/*
 * Keeps a polling service running for a widget only while the widget is in view.
 *
 * Services poll only while something watches them. A widget used to watch from
 * the moment it existed, so with windows over the desktop the shell went on
 * reading processor load and the GPU every second for widgets nobody could see.
 * `live` comes from the canvas, which knows when its desktop is covered.
 */
QtObject {
    id: root

    required property var service
    property bool live: true
    property bool held: false

    function sync() {
        if (root.live && !root.held) {
            root.service.watch();
            root.held = true;
        } else if (!root.live && root.held) {
            root.service.unwatch();
            root.held = false;
        }
    }

    onLiveChanged: root.sync()
    Component.onCompleted: root.sync()
    Component.onDestruction: {
        if (root.held)
            root.service.unwatch();
    }
}
