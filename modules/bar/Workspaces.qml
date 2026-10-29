import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Workspace indicator: fixed slots with a capsule that travels between them.
 *
 * The capsule's two edges animate at different durations, so the leading edge
 * runs ahead and the trailing edge catches up — the capsule stretches across the
 * gap and settles. That asymmetry is the whole effect; animating x and width
 * together just slides a rigid shape and reads as flat.
 *
 * Slots are uniform and wide enough for the capsule, so neighbouring dots never
 * end up sitting underneath it.
 */
Item {
    id: root

    required property string monitorName

    readonly property int count: Config.forMonitor(monitorName, "bar.workspaces.count", 6)
    readonly property real slot: Config.forMonitor(monitorName, "bar.workspaces.slot", 15)
    readonly property real gap: Config.forMonitor(monitorName, "bar.workspaces.gap", 4)
    readonly property real dotSize: Config.forMonitor(monitorName, "bar.workspaces.dotSize", 5)
    readonly property real trailFactor: Config.forMonitor(monitorName, "bar.workspaces.trailFactor", 1.6)

    readonly property int activeId: Hypr.focusedWorkspace?.id ?? 1
    // Special workspaces report ids outside the range; hold the capsule where it is.
    readonly property int activeIndex: Math.max(0, Math.min(count - 1, activeId - 1))

    // Capsule edges, driven independently.
    property real capsuleLeft: 0
    property real capsuleRight: slot

    implicitWidth: count * slot + (count - 1) * gap
    implicitHeight: Math.max(dotSize, 11)

    function slotX(index) {
        return index * (slot + gap);
    }

    function travel() {
        const target = slotX(activeIndex);
        const goingRight = target > capsuleLeft;
        const lead = Theme.standard;
        const trail = Math.round(lead * trailFactor);

        leftAnim.stop();
        rightAnim.stop();

        leftAnim.to = target;
        rightAnim.to = target + slot;
        // The edge in front moves first; the one behind lags, stretching the shape.
        leftAnim.duration = goingRight ? trail : lead;
        rightAnim.duration = goingRight ? lead : trail;

        leftAnim.start();
        rightAnim.start();
    }

    onActiveIndexChanged: travel()

    Component.onCompleted: {
        capsuleLeft = slotX(activeIndex);
        capsuleRight = capsuleLeft + slot;
    }

    NumberAnimation {
        id: leftAnim

        target: root
        property: "capsuleLeft"
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.enterEasing
    }

    NumberAnimation {
        id: rightAnim

        target: root
        property: "capsuleRight"
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.enterEasing
    }

    Rectangle {
        id: capsule

        x: root.capsuleLeft
        width: Math.max(root.dotSize, root.capsuleRight - root.capsuleLeft)
        height: root.dotSize
        radius: height / 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.dotOn
    }

    Repeater {
        model: root.count

        Item {
            id: cell

            required property int index

            readonly property int wsId: index + 1
            readonly property bool active: root.activeIndex === index
            readonly property bool occupied: Hypr.isOccupied(wsId)
            readonly property int windows: Hypr.windowsOn(wsId)

            x: root.slotX(index)
            width: root.slot
            height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: root.dotSize
                height: root.dotSize
                radius: height / 2
                // Inverts where the capsule covers it, so the capsule reads as a
                // highlight rather than something sitting on top of the dot.
                color: {
                    if (cell.active)
                        return Theme.surface;
                    return cell.occupied ? Qt.alpha(Theme.fg, 0.55) : Theme.dotOff;
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.standard
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.focusWorkspace(cell.wsId)
            }
        }
    }
}
