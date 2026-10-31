pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The lock screen itself: a pure picture of the state in `auth`, with no idea
 * whether it is on a real session lock or a preview window. That split is what
 * lets it be built and looked at without risking the session.
 */
FocusScope {
    id: root

    required property var auth

    // 1 at 1080 tall. Everything scales from this, so the same layout fits the
    // 1080p and the ultrawide without either being a cropped copy of the other.
    readonly property real u: Math.max(0.6, root.height / 1080)

    // Escape with nothing typed, for a preview window to close itself on. A real
    // lock never connects to this.
    signal escaped

    readonly property string greeting: {
        const h = Time.hours;
        if (h >= 5 && h < 12)
            return "Good morning";
        if (h >= 12 && h < 17)
            return "Good afternoon";
        if (h >= 17)
            return "Good evening";
        return "Up late";
    }

    readonly property string weatherLine: {
        if (!Weather.ready)
            return "";
        const parts = [`${Math.round(Weather.temperature)}° ${Weather.condition}`];
        if (Weather.place.length > 0)
            parts.push(Weather.place);
        return parts.join(" · ");
    }

    /*
     * Arriving, the parts settle into place one after another — date, clock,
     * weather, then the way in — each dropping or rising a little as it fades
     * up, so locking reads as the screen composing itself rather than a cut.
     *
     * Leaving, the ring round the picture fills with the accent, and then the
     * whole screen draws in toward the middle and fades: the top lifts, the
     * bottom sinks, everything shrinks a touch. Lock.qml waits for it.
     */
    property real appear: 0
    property real leave: 0
    property real ringFill: 0
    // Kept for anything still reading it.
    readonly property bool shown: root.appear > 0

    // How far along one part is, starting `delay` into the arrival.
    function part(delay) {
        return Math.max(0, Math.min(1, (root.appear - delay) / 0.45));
    }

    NumberAnimation {
        id: arrive

        target: root
        property: "appear"
        from: 0
        to: 1
        duration: Math.max(1, Theme.speed * 1100)
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.soft
    }

    SequentialAnimation {
        id: depart

        NumberAnimation {
            target: root
            property: "ringFill"
            to: 1
            duration: Math.max(1, Theme.speed * 260)
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: root
            property: "leave"
            to: 1
            duration: Math.max(1, Theme.speed * 380)
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.soft
        }
    }

    Connections {
        target: root.auth

        function onPhaseChanged() {
            if (root.auth.phase === "success")
                depart.start();
        }
    }

    focus: true
    Component.onCompleted: {
        root.forceActiveFocus();
        arrive.start();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape && root.auth.length === 0)
            root.escaped();
        root.auth.handleKey(event);
        event.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Item {
        id: stage

        anchors.fill: parent
        opacity: 1 - root.leave
        scale: 1 - 0.05 * root.leave

        StatusCorner {
            opacity: root.part(0.45)
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 40 * root.u
            anchors.rightMargin: 56 * root.u
            u: root.u
        }

        // Date, time, weather: one centred stack in the upper half.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.16 - root.leave * 40 * root.u
            spacing: 22 * root.u

            LockLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                u: root.u * 1.15
                text: Qt.formatDate(Time.now, "dddd · d MMMM")
                opacity: root.part(0)
                transform: Translate { y: (1 - root.part(0)) * -18 * root.u }
            }

            ClockFace {
                anchors.horizontalCenter: parent.horizontalCenter
                time: Time.now
                size: 250 * root.u
                opacity: root.part(0.1)
                transform: Translate { y: (1 - root.part(0.1)) * -28 * root.u }
            }

            LockLabel {
                anchors.horizontalCenter: parent.horizontalCenter
                u: root.u * 1.05
                dim: true
                text: root.weatherLine
                visible: text.length > 0
                opacity: root.part(0.22)
                transform: Translate { y: (1 - root.part(0.22)) * -14 * root.u }
            }
        }

        Row {
            opacity: root.part(0.45)
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: 56 * root.u
            anchors.bottomMargin: 44 * root.u
            spacing: 12 * root.u

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: Notifs.dnd ? "bell-off" : "bell"
                size: 17 * root.u
                color: Theme.fgDim
            }

            // A count, never the contents: anyone can read a locked screen.
            LockLabel {
                anchors.verticalCenter: parent.verticalCenter
                u: root.u
                text: Notifs.count === 1 ? "1 notification" : `${Notifs.count > 0 ? Notifs.count : "no"} notifications`
            }
        }

        // The way in: picture, greeting, password.
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.1 - root.leave * 40 * root.u
            spacing: 14 * root.u
            opacity: root.part(0.32)
            transform: Translate { y: (1 - root.part(0.32)) * 36 * root.u }

            Avatar {
                anchors.horizontalCenter: parent.horizontalCenter
                size: 156 * root.u
                fill: root.ringFill
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: `${root.greeting} ${Account.firstName}`
                color: Theme.fg
                font.family: Theme.fontRounded
                font.pixelSize: 26 * root.u
                font.variableAxes: ({ "wght": 560 })
                renderType: Text.NativeRendering
            }

            PasswordBox {
                anchors.horizontalCenter: parent.horizontalCenter
                auth: root.auth
                u: root.u
            }

            // Room is always kept for this line so nothing moves when it appears.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 1
                height: 18 * root.u

                LockLabel {
                    id: message

                    anchors.horizontalCenter: parent.horizontalCenter
                    u: root.u
                    color: Theme.danger
                    text: {
                        switch (root.auth.phase) {
                        case "failed":
                            return "wrong password · try again";
                        case "error":
                            return "something went wrong · try again";
                        case "maxtries":
                            return root.auth.notice.length > 0 ? root.auth.notice.split("\n")[0] : "too many attempts";
                        default:
                            return "";
                        }
                    }
                    opacity: text.length > 0 ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.standard
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.smooth
                        }
                    }
                }
            }
        }
    }
}
