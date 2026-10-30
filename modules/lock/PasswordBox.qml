pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

/*
 * Where the password goes: a pill of dots.
 *
 * Every dot is a slot that always exists and merely changes state, rather than a
 * delegate created per keystroke and destroyed per backspace. Creating and
 * destroying children is what makes typing in a box like this feel jerky: the row
 * re-lays-out instantly, the new dot pops in at full size, and a deleted one
 * simply vanishes. Here a slot's width, its dot's size and its colour are all
 * animated, so the row opens up to make room for each character and closes behind
 * each deletion, and the others slide to follow.
 *
 * Six dim dots are always there as the resting state, and typing fills them in.
 */
Item {
    id: root

    required property var auth
    property real u: 1

    readonly property int resting: 6
    readonly property int slots: 40
    readonly property real pitch: 26 * root.u
    readonly property real dot: 11 * root.u

    readonly property bool bad: root.auth.phase === "failed" || root.auth.phase === "error" || root.auth.phase === "maxtries"
    readonly property bool checking: root.auth.phase === "checking"

    implicitWidth: 400 * root.u
    implicitHeight: 62 * root.u

    // Moves as a whole when an attempt is refused.
    property real shake: 0

    Connections {
        target: root.auth

        function onRejected() {
            shaking.restart();
        }
    }

    SequentialAnimation {
        id: shaking

        NumberAnimation { target: root; property: "shake"; to: -14 * root.u; duration: 55; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shake"; to: 12 * root.u; duration: 90; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shake"; to: -8 * root.u; duration: 90; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shake"; to: 4 * root.u; duration: 80; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: 90; easing.type: Easing.OutQuad }
    }

    Rectangle {
        id: pill

        x: root.shake
        width: parent.width
        height: parent.height
        radius: height / 2
        color: Theme.panel
        border.width: root.bad ? Math.max(1.5, 1.5 * root.u) : 1
        border.color: root.bad ? Theme.danger : (root.auth.length > 0 ? Theme.fgFaint : Theme.lineHi)

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.standard
            }
        }

        Row {
            id: dots

            anchors.centerIn: parent

            // Pulses while the answer is awaited, so there is something to see
            // between Enter and the result.
            opacity: 1

            SequentialAnimation on opacity {
                running: root.checking
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation { to: 0.35; duration: 420; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 420; easing.type: Easing.InOutSine }
            }

            Repeater {
                model: root.slots

                Item {
                    id: slot

                    required property int index

                    readonly property bool typed: slot.index < root.auth.length
                    readonly property bool present: slot.index < Math.max(root.resting, root.auth.length)

                    width: slot.present ? root.pitch : 0
                    height: root.dot

                    // The row opens to make room, and closes behind a deletion.
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.standard + 40
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.soft
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.dot
                        height: width
                        radius: width / 2
                        color: root.bad ? Theme.danger : (slot.typed ? Theme.fg : Theme.fgFaint)
                        // A typed dot is full size, a resting one a little smaller, and one
                        // with nothing behind it has shrunk away.
                        scale: !slot.present ? 0 : (slot.typed ? 1 : 0.72)
                        opacity: slot.present ? 1 : 0

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.standard + 60
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.soft
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.standard
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.standard
                            }
                        }
                    }
                }
            }
        }
    }
}
