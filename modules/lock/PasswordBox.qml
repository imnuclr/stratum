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
 * Empty, it says what it wants — "password"; a lone dot sitting there
 * read as a glitch. Each character is a dot, the row opening outward from the
 * centre.
 */
Item {
    id: root

    required property var auth
    property real u: 1

    readonly property int resting: 0
    readonly property int slots: 40
    // As many dots as the pill holds; a longer password keeps typing, it just
    // stops drawing more, so the row never runs out of the box.
    // Room is kept at the right for the overflow count.
    readonly property int fits: Math.max(1, Math.floor((root.width - 96 * root.u) / root.pitch))
    // Characters past what the row shows.
    readonly property int extra: Math.max(0, root.auth.length - root.fits)
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

        NumberAnimation { target: root; property: "shake"; to: -14 * root.u; duration: 40; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "shake"; to: 12 * root.u; duration: 65; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shake"; to: -8 * root.u; duration: 65; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shake"; to: 4 * root.u; duration: 60; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "shake"; to: 0; duration: 65; easing.type: Easing.OutQuad }
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
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        // Empty: what to do, said once, quietly.
        Text {
            id: hint

            anchors.centerIn: parent
            text: root.checking ? "checking…" : "password"
            color: Theme.fgFaint
            font.family: Theme.fontRounded
            font.pixelSize: 17 * root.u
            font.variableAxes: ({ "wght": 450 })
            renderType: Text.NativeRendering
            opacity: root.auth.length === 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.standard
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }
        }

        // How many more there are than dots, at the right end of the pill.
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 20 * root.u
            anchors.verticalCenter: parent.verticalCenter
            text: `+${root.extra}`
            color: root.bad ? Theme.danger : Theme.fgDim
            font.family: Theme.fontRounded
            font.pixelSize: 15 * root.u
            font.variableAxes: ({ "wght": 600 })
            renderType: Text.NativeRendering
            opacity: root.extra > 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.standard
                }
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

                NumberAnimation { to: 0.35; duration: 320; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 320; easing.type: Easing.InOutSine }
            }

            Repeater {
                model: root.slots

                Item {
                    id: slot

                    required property int index

                    readonly property bool typed: slot.index < root.auth.length
                    readonly property bool present: slot.index < Math.min(root.fits, Math.max(root.resting, root.auth.length))

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
                        id: mark

                        // Past the end of the row, the last dot pops on every
                        // keystroke, so typing still visibly lands somewhere.
                        property real pop: 1

                        anchors.centerIn: parent
                        width: root.dot * mark.pop
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
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.smooth
                            }
                        }

                        SequentialAnimation {
                            id: popping

                            NumberAnimation { target: mark; property: "pop"; to: 1.45; duration: 60; easing.type: Easing.OutQuad }
                            NumberAnimation { target: mark; property: "pop"; to: 1; duration: 160; easing.type: Easing.OutCubic }
                        }

                        Connections {
                            target: root.auth

                            function onLengthChanged() {
                                if (root.extra > 0 && slot.index === root.fits - 1)
                                    popping.restart();
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
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
}
