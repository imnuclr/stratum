pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Notifications as they arrive, at the top right.
 *
 * The same corner as the notification page, because that page is this corner's
 * history: dismissing a toast and going to look for it later lead to the same
 * place. Only the focused monitor shows them — a notification repeated on every
 * display is noise, and the one being looked at is the one worth interrupting.
 *
 * The model is the server's own list, not a separate list of what is toasting.
 * A JavaScript array of "currently showing" would reset the view on every arrival
 * and expiry, destroying the delegates mid-animation, which is the whole point of
 * having them. Instead every tracked notification gets a delegate and each one
 * decides for itself whether it is still worth showing: expiry is a delegate
 * collapsing, not a model change.
 */
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        readonly property int toastMs: Config.get("notifications.toastMs", 5000)
        readonly property real toastWidth: Config.get("notifications.width", 380)

        screen: modelData
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "stratum-toasts"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusionMode: ExclusionMode.Ignore

        // Kept mapped so the list has a settled layout before the first toast
        // arrives, rather than measuring itself in the frames it appears in.
        visible: true
        color: "transparent"

        anchors.top: true
        anchors.right: true

        implicitWidth: win.toastWidth + Theme.space(2) * 2
        implicitHeight: win.modelData.height

        /*
         * Hidden while the notification page is up — it is the same corner and
         * the same notifications — and while do not disturb is on, which is what
         * do not disturb means.
         */
        readonly property bool muted: Notifs.dnd
            || Shell.openPanel === "notifications"
            || !win.focused

        // The display being worked on. A toast repeated on every monitor is
        // noise, and the one being looked at is the one worth interrupting.
        readonly property bool focused: Hypr.focusedWorkspace?.monitor?.name === win.modelData.name

        // Only the rows actually on screen take the pointer; everything else on
        // this surface has to stay click-through.
        mask: Region {
            x: Theme.space(2)
            y: Config.get("bar.margin", 10) + Theme.space(1)
            width: win.muted ? 0 : win.toastWidth
            height: win.muted ? 0 : Math.ceil(list.contentHeight)
        }

        ListView {
            id: list

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Config.get("bar.margin", 10) + Theme.space(1)
            anchors.rightMargin: Theme.space(2)

            width: win.toastWidth
            height: Math.min(contentHeight, win.modelData.height * 0.8)
            interactive: false
            // Newest nearest the top, where the eye already is.
            verticalLayoutDirection: ListView.BottomToTop

            model: Notifs.model

            // A toast that has gone has no height, so the view has nothing to
            // show until one arrives.
            visible: !win.muted && height > 1
            opacity: win.muted ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            displaced: Transition {
                NumberAnimation {
                    properties: "y"
                    duration: Theme.popoutMs
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }
            }

            /*
             * Arrives as a small pill at the top, widens and drops into the full
             * card, and only then fills in; leaves by the same road backwards —
             * the words go first, then the card closes back into the pill.
             *
             * One number, `p`, runs the whole thing: 0 is the pill, 1 the card.
             * Size follows it directly, the content fades in over its last
             * third, and the slot in the list opens just ahead of the pill so
             * the toasts below are already moving aside as it appears.
             *
             * `p` is animated explicitly rather than through Behaviors because a
             * fresh toast is born already live: Behaviors enabled only after
             * creation never saw the change and it simply popped in.
             */
            delegate: Item {
                id: toast

                required property var modelData

                readonly property bool critical: toast.modelData?.urgency === NotificationUrgency.Critical
                readonly property int timeout: toast.modelData?.expireTimeout > 0
                    ? toast.modelData.expireTimeout
                    : win.toastMs

                /*
                 * Whether this one is still announcing itself. Assigned once, on
                 * creation, rather than bound: a binding on arrival times
                 * re-evaluates every time another notification lands, which would
                 * bring every expired toast back at once.
                 */
                property bool live: false
                // 0: the pill. 1: the card.
                property real p: 0

                readonly property real pillWidth: 64
                readonly property real pillHeight: 34
                readonly property real fullHeight: row.implicitHeight
                // The slot opens in the first stretch, so a small p already has room.
                readonly property real slot: Math.min(1, toast.p * 8)

                Component.onCompleted: toast.live = Notifs.fresh(toast.modelData, toast.timeout)

                onLiveChanged: {
                    grow.to = toast.live ? 1 : 0;
                    grow.duration = toast.live ? Math.round(Theme.popoutMs * 0.75) : Math.round(Theme.popoutExitMs * 0.8);
                    grow.restart();
                }

                NumberAnimation {
                    id: grow

                    target: toast
                    property: "p"
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }

                width: list.width
                height: Math.round((card.height + Theme.space(2)) * toast.slot)

                Rectangle {
                    id: card

                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: toast.pillWidth + (toast.width - toast.pillWidth) * toast.p
                    height: toast.pillHeight + (toast.fullHeight - toast.pillHeight) * toast.p
                    radius: Math.min(height / 2, Theme.rTile)
                    color: linger.hovered ? Qt.lighter(Theme.deep, 3) : Theme.deep
                    border.width: 1
                    border.color: linger.hovered ? Theme.fg : Theme.outline
                    opacity: toast.slot
                    clip: true
                    visible: toast.p > 0.001

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.micro
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: Theme.micro
                        }
                    }

                    NotificationRow {
                        id: row

                        anchors.top: parent.top
                        anchors.right: parent.right
                        width: toast.width
                        notification: toast.modelData
                        // The card behind it is the surface, and it is what changes
                        // shape; this only carries the words.
                        color: "transparent"
                        border.width: 0
                        opacity: Math.max(0, Math.min(1, (toast.p - 0.45) / 0.4))
                    }
                }

                HoverHandler {
                    id: linger
                }

                /*
                 * Critical notifications do not expire: the standard says they
                 * stay until acted on, and they are the ones worth obeying it
                 * for. Hovering holds any toast open — reading one should not be
                 * a race.
                 */
                Timer {
                    interval: toast.timeout
                    running: toast.live && !toast.critical && !linger.hovered && !win.muted
                    onTriggered: toast.live = false
                }
            }
        }
    }
}
