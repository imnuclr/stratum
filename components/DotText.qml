import QtQuick
import qs.theme

/*
 * Dot-matrix numerals. Characters are laid out individually so a change can
 * cascade across them rather than cross-fading the whole string — the shell's
 * signature transition. Pass `plain: true` to skip the animation.
 */
Row {
    id: root

    property string text: ""
    property real size: 20
    property int weight: Font.Bold
    property color color: Theme.fg
    property bool plain: false

    spacing: 0

    Repeater {
        model: root.text.length

        Item {
            id: cell

            required property int index
            readonly property string char: root.text[index]

            implicitWidth: glyph.implicitWidth
            implicitHeight: glyph.implicitHeight

            Text {
                id: glyph

                text: cell.char
                color: root.color
                font.family: Theme.fontDot
                font.pixelSize: root.size
                font.weight: root.weight
                font.features: ({ tnum: 1 })
                renderType: Text.NativeRendering
            }

            // Re-run the reveal whenever this position's character changes.
            onCharChanged: if (!root.plain) reveal.restart()

            SequentialAnimation {
                id: reveal

                PauseAnimation {
                    duration: cell.index * Theme.dotStagger
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: glyph
                        property: "opacity"
                        from: 0.15
                        to: 1
                        duration: Theme.micro
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: glyph
                        property: "scale"
                        from: 0.82
                        to: 1
                        duration: Theme.micro
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }
}
