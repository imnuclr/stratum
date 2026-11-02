import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The focus modes, for the card above the control centre: one row each, the
 * one that is on lit up, and under it how long it lasts. Tapping another mode
 * moves to it; tapping the one that is on turns it off.
 */
Column {
    id: root

    spacing: Theme.space(2)

    SectionLabel {
        text: "focus"
    }

    Repeater {
        model: Focus.shown

        Column {
            id: entry

            required property var modelData

            readonly property bool current: Focus.mode === entry.modelData.id

            width: root.width
            spacing: Theme.space(2)

            Rectangle {
                width: parent.width
                height: 44
                radius: height / 2
                color: entry.current ? Theme.fg : (hover.hovered ? Theme.surfaceTop : Theme.surfaceHi)

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.space(4)
                    spacing: Theme.space(3)

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: entry.modelData.icon
                        size: 17
                        color: entry.current ? Theme.bg : Theme.fgBright
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.name
                        color: entry.current ? Theme.bg : Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.space(4)
                    visible: entry.current
                    text: Focus.untilLabel
                    color: Theme.bg
                    opacity: 0.7
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: entry.current ? Focus.stop() : Focus.set(entry.modelData.id, "off")
                }
            }

            // How long, for the one that is on.
            Row {
                visible: entry.current
                x: Theme.space(2)
                spacing: Theme.space(2)

                Repeater {
                    model: [
                        { length: "off", label: "until off" },
                        { length: "hour", label: "1 hour" },
                        { length: "morning", label: "until morning" }
                    ]

                    Rectangle {
                        id: choice

                        required property var modelData

                        width: choiceLabel.implicitWidth + Theme.space(4)
                        height: 28
                        radius: height / 2
                        color: choiceHover.hovered ? Theme.surfaceTop : Theme.surfaceHi

                        SectionLabel {
                            id: choiceLabel

                            anchors.centerIn: parent
                            text: choice.modelData.label
                            color: Theme.fg
                        }

                        HoverHandler {
                            id: choiceHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: Focus.set(entry.modelData.id, choice.modelData.length)
                        }
                    }
                }
            }
        }
    }
}
