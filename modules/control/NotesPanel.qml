import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The to-do menu: one field to add a task, then every task below it.
 *
 * Open tasks first, completed ones under "done". Adding, removing and ticking
 * something off all animate — a task that is finished slides down to the done
 * group rather than disappearing from under the pointer, which is the thing
 * that makes a list read as a list rather than as a set that was replaced.
 */
Item {
    id: root

    function submit() {
        if (field.text.trim().length === 0)
            return;
        Notes.add(field.text);
        field.text = "";
        // Keep the field for the next task; writing several down in a row
        // should not mean clicking back into it each time.
        field.take();
        list.positionViewAtBeginning();
    }

    Row {
        id: composer

        width: parent.width
        spacing: Theme.space(2)

        TextField {
            id: field

            width: parent.width - add.width - Theme.space(2)
            height: 34
            radius: 17
            placeholder: "add a task…"

            onAccepted: root.submit()
        }

        Rectangle {
            id: add

            readonly property bool ready: field.text.trim().length > 0

            width: 34
            height: 34
            radius: width / 2
            color: ready && addHover.hovered ? Theme.fg : Theme.surfaceTop
            opacity: ready ? 1 : 0.5
            scale: addHover.hovered ? 1.06 : 1

            Behavior on color {
                ColorAnimation {
                    duration: Theme.micro
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.micro
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.gentle
                }
            }

            Glyph {
                anchors.centerIn: parent
                name: "plus"
                size: 14
                color: add.ready && addHover.hovered ? Theme.bg : Theme.fg
            }

            HoverHandler {
                id: addHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: root.submit()
            }
        }
    }

    ListView {
        id: list

        anchors.top: composer.bottom
        anchors.topMargin: Theme.space(3)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        model: Notes.items
        spacing: 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        // The model keeps open tasks first, so this is one boundary and one
        // quiet heading rather than a sort the view has to do.
        section.property: "group"
        section.delegate: Item {
            width: ListView.view.width
            height: section === "done" ? 28 : 0

            SectionLabel {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.space(1)
                visible: section === "done"
                dim: true
                text: "done"
            }
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }

            NumberAnimation {
                property: "scale"
                from: 0.96
                to: 1
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.expressive
            }
        }

        populate: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.sheetMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }

            NumberAnimation {
                property: "x"
                to: Theme.space(6)
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        move: Transition {
            NumberAnimation {
                property: "y"
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        delegate: Item {
            id: row

            required property string key
            required property string text
            required property bool done

            width: list.width
            height: 32

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -Theme.space(1)
                anchors.rightMargin: -Theme.space(1)
                radius: Theme.rInner
                color: rowHover.hovered ? Qt.alpha(Theme.fg, 0.06) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }
            }

            Rectangle {
                id: box

                anchors.verticalCenter: parent.verticalCenter
                width: 16
                height: 16
                radius: width / 2
                color: row.done ? Theme.fg : "transparent"
                border.width: 1
                border.color: row.done ? Theme.fg : Theme.lineHi

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Glyph {
                    anchors.centerIn: parent
                    name: "check"
                    size: 9
                    color: Theme.bg
                    opacity: row.done ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.standard
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.smooth
                        }
                    }
                }
            }

            Text {
                anchors.left: box.right
                anchors.leftMargin: Theme.space(2)
                anchors.right: remove.left
                anchors.rightMargin: Theme.space(2)
                anchors.verticalCenter: parent.verticalCenter
                text: row.text
                elide: Text.ElideRight
                color: row.done ? Theme.fgFaint : Theme.fgBright
                font.family: Theme.fontUi
                font.pixelSize: 13
                font.strikeout: row.done
                renderType: Text.NativeRendering

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }
            }

            Glyph {
                id: remove

                anchors.right: parent.right
                anchors.rightMargin: Theme.space(1)
                anchors.verticalCenter: parent.verticalCenter
                name: "close"
                size: 11
                opacity: rowHover.hovered ? 1 : 0.5
                color: removeHover.hovered ? Theme.fg : Theme.fgFaint

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }

                HoverHandler {
                    id: removeHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Notes.remove(row.key)
                }
            }

            MouseArea {
                anchors.fill: parent
                // The close glyph keeps its own strip, so a press meant to
                // delete does not also tick the task off.
                anchors.rightMargin: Theme.space(4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notes.toggle(row.key)
            }

            HoverHandler {
                id: rowHover

                blocking: false
            }
        }
    }

    SectionLabel {
        anchors.centerIn: list
        visible: Notes.count === 0
        dim: true
        text: "nothing to do"
    }
}
