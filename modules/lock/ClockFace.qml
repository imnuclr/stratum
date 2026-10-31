pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.theme

/*
 * The time, in a soft round face.
 *
 * Each digit lives in a cell of fixed width. A proportional face makes the whole
 * time shift sideways whenever a narrow digit — a 1 — rolls into a wide one, and
 * on something this large that reads as the clock twitching every minute.
 * Digits roll over when they change: the old one lifts away as the new one
 * settles in, so a minute passing is a motion rather than a swap.
 */
Item {
    id: root

    property date time: new Date()
    property real size: 230
    property color colour: Theme.fg

    readonly property string hh: Time.hourOf(root.time, Time.twelveHour, true)
    readonly property string mm: Qt.formatTime(root.time, "mm")

    // Widest digit in the face, so every cell is as wide as the worst case.
    TextMetrics {
        id: metrics

        font.family: Theme.fontRounded
        font.pixelSize: root.size
        font.variableAxes: ({ "wght": 420 })
        text: "0"
    }

    readonly property real cell: Math.ceil(metrics.advanceWidth * 1.02)

    implicitWidth: row.width
    implicitHeight: Math.ceil(metrics.height)

    Row {
        id: row

        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.size * 0.02

        Repeater {
            model: [
                { kind: "digit", part: "hh", index: 0 },
                { kind: "digit", part: "hh", index: 1 },
                { kind: "colon", part: "", index: 0 },
                { kind: "digit", part: "mm", index: 0 },
                { kind: "digit", part: "mm", index: 1 }
            ]

            Item {
                id: slot

                required property var modelData

                readonly property bool colon: slot.modelData.kind === "colon"
                readonly property string wanted: slot.colon ? "" : (slot.modelData.part === "hh" ? root.hh : root.mm).charAt(slot.modelData.index)

                property string shown: ""
                property string old: ""
                property bool primed: false

                width: slot.colon ? root.size * 0.22 : root.cell
                height: root.implicitHeight

                Component.onCompleted: {
                    slot.shown = slot.wanted;
                    slot.primed = true;
                }

                onWantedChanged: {
                    if (!slot.primed || slot.colon || slot.wanted === slot.shown)
                        return;
                    slot.old = slot.shown;
                    slot.shown = slot.wanted;
                    roll.restart();
                }

                Text {
                    id: leaving

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: slot.old
                    opacity: 0
                    color: root.colour
                    font.family: Theme.fontRounded
                    font.pixelSize: root.size
                    font.variableAxes: ({ "wght": 420 })
                    renderType: Text.NativeRendering
                }

                Text {
                    id: arriving

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: slot.shown
                    visible: !slot.colon
                    color: root.colour
                    font.family: Theme.fontRounded
                    font.pixelSize: root.size
                    font.variableAxes: ({ "wght": 420 })
                    renderType: Text.NativeRendering
                }

                // The colon: two round dots, standing in for the face's own glyph
                // so it sits at the optical centre of the digits.
                Column {
                    visible: slot.colon
                    anchors.centerIn: parent
                    spacing: root.size * 0.2

                    Repeater {
                        model: 2

                        Rectangle {
                            width: root.size * 0.075
                            height: width
                            radius: width / 2
                            color: Theme.fgDim
                        }
                    }
                }

                ParallelAnimation {
                    id: roll

                    NumberAnimation {
                        target: leaving
                        property: "opacity"
                        from: 1
                        to: 0
                        duration: Theme.sheetMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }

                    NumberAnimation {
                        target: leaving
                        property: "y"
                        from: 0
                        to: -root.size * 0.12
                        duration: Theme.sheetMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }

                    NumberAnimation {
                        target: arriving
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: Theme.sheetMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }

                    NumberAnimation {
                        target: arriving
                        property: "y"
                        from: root.size * 0.12
                        to: 0
                        duration: Theme.sheetMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }
                }
            }
        }
    }
}
