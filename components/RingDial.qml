import QtQuick
import qs.theme

/*
 * A dotted ring you set by dragging it up or down, or by scrolling over it, with
 * its reading in the middle and its name beneath.
 *
 * The ring and the number follow the pointer at once, but `committed` is only
 * emitted when the drag ends or the wheel has been still for a moment. What this
 * sets is often expensive to redraw (a whole wallpaper in dots), and asking for
 * that on every pixel of a drag would make the control the slow part.
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

    signal committed(real value)

    implicitWidth: size
    implicitHeight: size + label.implicitHeight + Theme.space(2)

    onValueChanged: {
        if (!drag.active && !settle.running)
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
            if (active)
                root.grabbed = root.live;
            else
                root.committed(root.live);
        }

        onTranslationChanged: {
            if (active)
                root.live = root.clamp(root.grabbed - translation.y / 180);
        }
    }

    WheelHandler {
        onWheel: event => {
            root.live = root.clamp(root.live + (event.angleDelta.y > 0 ? 0.04 : -0.04));
            settle.restart();
        }
    }

    Timer {
        id: settle

        interval: 220
        onTriggered: root.committed(root.live)
    }

    HoverHandler {
        cursorShape: Qt.SizeVerCursor
    }
}
