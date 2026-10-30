pragma ComponentBehavior: Bound

import QtQuick
import qs.theme

/*
 * Pick one from a list that is too long for a segmented control: the current
 * choice on a pill, and the rest unfolding beneath it when clicked.
 *
 * It unfolds in place rather than floating over the page, so nothing beneath
 * can cover it and a scrolling page cannot clip it. `extra` is how much taller
 * it is while open, which a SettingRow adds to its own height.
 */
Column {
    id: root

    // Labels to show.
    property var model: []
    property int current: 0
    property real menuWidth: 220
    property bool open: false

    readonly property real extra: list.height

    signal picked(int index)

    width: root.menuWidth
    spacing: 0

    Rectangle {
        width: parent.width
        height: 34
        radius: height / 2
        color: hover.hovered || root.open ? Theme.surfaceTop : Theme.surface
        border.width: 1
        border.color: root.open ? Theme.lineHi : Theme.line

        Behavior on color {
            ColorAnimation {
                duration: Theme.micro
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        Text {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space(4)
            anchors.right: chevron.left
            anchors.rightMargin: Theme.space(2)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: root.model[root.current] ?? ""
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 13
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Glyph {
            id: chevron

            anchors.right: parent.right
            anchors.rightMargin: Theme.space(3)
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron-down"
            size: 14
            color: Theme.fgDim
            rotation: root.open ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.standard * 1.6
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.open = !root.open
        }
    }

    Item {
        id: list

        width: parent.width
        height: root.open ? Math.min(options.implicitHeight, 260) + Theme.space(1) : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Theme.sheetMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        Rectangle {
            y: Theme.space(1)
            width: parent.width
            height: Math.min(options.implicitHeight, 260)
            radius: Theme.rInner
            color: Theme.surface
            border.width: 1
            border.color: Theme.line

            Flickable {
                anchors.fill: parent
                anchors.margins: 4
                contentHeight: options.implicitHeight - 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: options

                    width: parent.width
                    bottomPadding: 8

                    Repeater {
                        model: root.model

                        Rectangle {
                            id: option

                            required property int index
                            required property string modelData

                            width: options.width
                            height: 30
                            radius: Theme.rInner - 4
                            color: optionHover.hovered ? Theme.surfaceTop : "transparent"

                            Glyph {
                                id: tick

                                anchors.left: parent.left
                                anchors.leftMargin: Theme.space(2)
                                anchors.verticalCenter: parent.verticalCenter
                                name: "check"
                                size: 13
                                color: Theme.fg
                                opacity: option.index === root.current ? 1 : 0
                            }

                            Text {
                                anchors.left: tick.right
                                anchors.leftMargin: Theme.space(2)
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: option.modelData
                                color: option.index === root.current ? Theme.fg : Theme.fgBright
                                font.family: Theme.fontUi
                                font.pixelSize: 13
                                renderType: Text.NativeRendering
                            }

                            HoverHandler {
                                id: optionHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: {
                                    root.open = false;
                                    root.picked(option.index);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
