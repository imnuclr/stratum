import QtQuick
import qs.theme

/*
 * Full-width action at the foot of a panel.
 */
Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property bool enabled: true
    property bool busy: false

    signal clicked

    implicitHeight: 30
    radius: Theme.rInner
    color: hover.containsMouse && enabled ? Theme.surfaceTop : Theme.surfaceHi
    border.width: 1
    border.color: hover.containsMouse && enabled ? Theme.lineHi : Theme.line
    opacity: enabled ? 1 : 0.4

    Behavior on color {
        ColorAnimation {
            duration: Theme.micro
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.space(1)
        opacity: root.busy ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.micro
            }
        }

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            // A button with only a label would otherwise keep an empty icon's
            // worth of space on its left and sit off-centre.
            visible: root.icon.length > 0
            name: root.icon
            size: 14
            color: Theme.fg
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 12
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }
    }

    // Busy state is a travelling dot rather than a spinner: the shell has no
    // other rotating element and one spinner would look borrowed.
    Rectangle {
        id: pulse

        visible: root.busy
        width: 5
        height: 5
        radius: 2.5
        color: Theme.fg
        y: (parent.height - height) / 2

        SequentialAnimation {
            running: root.busy
            loops: Animation.Infinite

            NumberAnimation {
                target: pulse
                property: "x"
                from: root.width * 0.3
                to: root.width * 0.7
                duration: 620
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: pulse
                property: "x"
                from: root.width * 0.7
                to: root.width * 0.3
                duration: 620
                easing.type: Easing.InOutCubic
            }
        }
    }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled && !root.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
