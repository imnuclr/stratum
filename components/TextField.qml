import QtQuick
import qs.theme

/*
 * Single-line input. Built on TextInput rather than Controls.TextField so it
 * carries no Qt styling to override.
 */
Rectangle {
    id: root

    property alias text: input.text
    property alias echoMode: input.echoMode
    property string placeholder: ""

    signal accepted(string text)

    implicitHeight: 28
    radius: Theme.rInner
    color: Theme.surfaceHi
    border.width: 1
    border.color: input.activeFocus ? Theme.fg : Theme.line

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.micro
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.smooth
        }
    }

    function take() {
        input.forceActiveFocus();
    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: Theme.space(2)
        anchors.rightMargin: Theme.space(2)
        verticalAlignment: Text.AlignVCenter
        color: Theme.fg
        font.family: Theme.fontUi
        font.pixelSize: 12
        selectByMouse: true
        selectionColor: Theme.fg
        selectedTextColor: Theme.surface
        clip: true

        onAccepted: root.accepted(text)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0
            text: root.placeholder
            color: Theme.fgFaint
            font.family: Theme.fontUi
            font.pixelSize: 12
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.IBeamCursor
    }
}
