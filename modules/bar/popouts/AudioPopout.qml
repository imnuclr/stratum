import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Output device and volume. The dot bar is draggable, so the popout is a control
 * rather than a readout.
 */
Item {
    id: root

    implicitWidth: 224
    implicitHeight: body.implicitHeight

    Column {
        id: body

        width: parent.width
        spacing: Theme.space(2)

        SectionLabel {
            text: "Output"
        }

        Text {
            text: Audio.sinkName.length > 0 ? Audio.sinkName : "No output"
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 14
            font.weight: Font.Medium
            width: root.width
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }

        Row {
            spacing: Theme.space(2)

            DotText {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.muted ? "──" : `${Math.round(Audio.volume * 100)}`
                size: 24
                color: Audio.muted ? Theme.fgFaint : Theme.fg
            }

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                dim: true
                text: Audio.muted ? "muted" : "%"
            }
        }

        Item {
            width: root.width
            height: 16

            DotBar {
                id: bar

                anchors.verticalCenter: parent.verticalCenter
                count: 24
                value: Audio.muted ? 0 : Audio.volume
                dotSize: 4
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                function apply(mouseX) {
                    Audio.setVolume(Math.max(0, Math.min(1, mouseX / width)));
                }

                onPressed: event => apply(event.x)
                onPositionChanged: event => {
                    if (pressed)
                        apply(event.x);
                }
                onWheel: event => Audio.step(event.angleDelta.y > 0 ? 0.02 : -0.02)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
        }

        Row {
            spacing: Theme.space(2)

            SectionLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: 62
                dim: true
                text: "Input"
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                name: "mic-off"
                size: 14
                color: Audio.sourceMuted ? Theme.warn : Theme.fgFaint
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.sourceMuted ? "Muted" : "Live"
                color: Theme.fgDim
                font.family: Theme.fontUi
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }
        }

        SectionLabel {
            width: body.width
            wrapMode: Text.WordWrap
            dim: true
            text: "Scroll to adjust · click to mute"
        }
    }
}
