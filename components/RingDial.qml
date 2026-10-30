import QtQuick
import qs.theme

/*
 * A dotted ring you set by dragging it up or down, or by scrolling over it, with
 * its reading in the middle and its name beneath.
 *
 * The ring and the number follow the pointer at once, and `committed` follows them
 * a few times a second while it moves, and once more when it stops, so whatever
 * the ring sets changes as it is turned.
 */
Item {
    id: root

    property real value: 0.5
    property string reading: ""
    property string caption: ""
    property real size: 104

    // Follows `value` except while being dragged.
    property real live: value
    property real grabbed: 0

    // Emitted while the ring is being moved, at most every 60ms, and once more
    // with the final value when it stops. The picture follows the ring as it
    // turns; the throttle is what keeps a large redraw from being asked for on
    // every pixel of the drag.
    signal committed(real value)

    property bool pending: false

    function push() {
        if (!throttle.running) {
            root.committed(root.live);
            throttle.start();
        } else {
            root.pending = true;
        }
    }

    implicitWidth: size
    implicitHeight: size + label.implicitHeight + Theme.space(2)

    onValueChanged: {
        if (!drag.active && !throttle.running)
            root.live = root.value;
    }

    function clamp(v) {
        return Math.max(0, Math.min(1, v));
    }

    DotRing {
        id: ring

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.size
        height: root.size
        count: 44
        dotSize: 4.2
        value: root.live
        // The ring is already following the pointer; easing behind it would feel
        // like lag.
        animated: false
    }

    Text {
        anchors.centerIn: ring
        text: root.reading
        color: Theme.fg
        font.family: Theme.fontDot
        font.pixelSize: 24
        font.weight: Font.Bold
        renderType: Text.NativeRendering
    }

    SectionLabel {
        id: label

        anchors.top: ring.bottom
        anchors.topMargin: Theme.space(2)
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.caption
        color: Theme.fgBright
    }

    DragHandler {
        id: drag

        target: null
        xAxis.enabled: false

        onActiveChanged: {
            if (active) {
                root.grabbed = root.live;
            } else {
                root.pending = false;
                root.committed(root.live);
            }
        }

        onTranslationChanged: {
            if (active) {
                root.live = root.clamp(root.grabbed - translation.y / 180);
                root.push();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton

        onWheel: wheel => {
            // A touchpad may report pixels and no angle.
            const d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y * 4;
            if (d === 0)
                return;
            root.live = root.clamp(root.live + (d > 0 ? 0.04 : -0.04));
            root.push();
        }
    }

    Timer {
        id: throttle

        interval: 60
        onTriggered: {
            if (root.pending) {
                root.pending = false;
                root.committed(root.live);
                throttle.start();
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.SizeVerCursor
    }
}
