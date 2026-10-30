import QtQuick
import qs.theme

/*
 * A number set by steps: minus, the value, plus. For settings measured in
 * pixels or counts, where a slider would make an exact value hard to hit.
 */
Row {
    id: root

    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property string suffix: ""

    signal moved(real value)

    spacing: Theme.space(1)

    component Button: Rectangle {
        id: button

        property string label: ""
        property real delta: 0

        width: 32
        height: 32
        radius: 16
        color: hover.hovered ? Theme.surfaceTop : Theme.surfaceHi

        Text {
            anchors.centerIn: parent
            text: button.label
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 16
            renderType: Text.NativeRendering
        }

        HoverHandler {
            id: hover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.moved(Math.max(root.from, Math.min(root.to, root.value + button.delta)))
        }
    }

    Button {
        label: "−"
        delta: -root.step
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        horizontalAlignment: Text.AlignHCenter
        text: `${Math.round(root.value * 100) / 100}${root.suffix}`
        color: Theme.fg
        font.family: Theme.fontUi
        font.pixelSize: 14
        font.weight: Font.Medium
        renderType: Text.NativeRendering
    }

    Button {
        label: "+"
        delta: root.step
    }
}
