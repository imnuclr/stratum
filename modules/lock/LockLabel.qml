import QtQuick
import qs.theme

/*
 * Caps micro-label at lock-screen scale: the shell's SectionLabel, but sized by
 * the screen it is on rather than fixed at 10px, since this one is read from
 * across a room rather than at arm's length.
 */
Text {
    property real u: 1
    property bool dim: false

    color: dim ? Theme.fgFaint : Theme.fgDim
    font.family: Theme.fontUi
    font.pixelSize: Math.round(12 * u)
    font.weight: Font.Medium
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 2 * u
    renderType: Text.NativeRendering
}
