import QtQuick
import qs.theme

/*
 * Caps micro-label. Every category heading in the shell is one of these.
 */
Text {
    property bool dim: false

    color: dim ? Theme.fgFaint : Theme.fgDim
    font.family: Theme.fontUi
    font.pixelSize: 10
    font.weight: Font.Medium
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 1.4
    renderType: Text.NativeRendering
}
