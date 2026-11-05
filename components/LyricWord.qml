import QtQuick
import QtQuick.Effects
import qs.theme

/*
 * One word of a lyric, lighting up as it is sung.
 *
 * Two copies of the same text, one dim and one bright, with the bright one
 * clipped to how far through the word the singing has got. That is the karaoke
 * sweep, and it is the reason the shell asks for word timings at all: a whole
 * line changing colour tells you which line, while a sweep tells you where in it
 * you are — which is the difference between following along and reading ahead.
 *
 * The clip is on an Item rather than drawn with a gradient because the sweep has
 * to be a hard edge. A gradient reads as a glow moving over the word, which is a
 * different and much vaguer thing: you cannot tell from it which letter is being
 * sung.
 *
 * The space after a word is this item's own padding, not a space character in
 * its text. Qt leaves trailing whitespace out of `implicitWidth` — the advance
 * is there when the text is drawn and gone when it is measured — so a word whose
 * text ended in a space was laid out at its width *without* one, and every word
 * in a line sat tight against the one before it with the glyphs running
 * together. Padding is measured, so it is there in both.
 */
Item {
    id: root

    property string text: ""
    // 0 before the word is sung, 1 once it is done.
    property real progress: 0
    property real size: 22
    property int weight: Font.DemiBold
    property color dim: Theme.fgFaint
    property color lit: Theme.fgBright
    // A space follows this word: true between words, false between the
    // syllables of one.
    property bool gapAfter: true
    // How far the word rises at its peak, and how much it swells, as a share of
    // its own size. Zero for places with no room for the motion.
    property real lift: 0.1
    property real swell: 0.06
    // A soft halo around the word while it is being sung. The one effect here
    // that costs a texture, so it is off for the lines that are only context.
    property bool glow: true
    /*
     * Leading, as a multiple of the type size. Carried on the word rather than
     * set on the Flow, because the Flow's row height is the tallest item in the
     * row — spacing it instead would put the air between the rows of a wrapped
     * line and none inside them.
     */
    property real leading: 1

    /*
     * Peaks in the middle of the word rather than at its end. Sung is sung: a
     * word still at its full lift once the next one has started reads as two
     * active words.
     */
    readonly property real emphasis: root.progress <= 0 || root.progress >= 1
        ? 0
        : Math.sin(root.progress * Math.PI)

    // Carried forward a moment after the word is done, so the settle back is a
    // movement rather than a jump at the instant progress reaches 1.
    readonly property real halo: root.glow ? root.emphasis : 0

    readonly property real gap: root.gapAfter ? spaceMetrics.advanceWidth : 0

    implicitWidth: base.implicitWidth + root.gap
    implicitHeight: Math.round(base.implicitHeight * root.leading)

    // The space advance for this exact font and size. Measured rather than
    // guessed at a fraction of the size: fonts differ, and a word space that is
    // wrong by a few per cent is visible across a line.
    TextMetrics {
        id: spaceMetrics

        font: base.font
        text: " "
    }

    Item {
        id: stage

        width: root.width
        height: root.height
        transformOrigin: Item.Bottom
        scale: 1 + root.swell * root.emphasis
        y: -root.size * root.lift * root.emphasis

        layer.enabled: root.halo > 0.01
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: root.lit
            shadowBlur: 1
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            shadowOpacity: 0.55 * root.halo
            blurMax: 24
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.micro
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        Text {
            id: base

            // Centred in the leading, so a wrapped line's two halves are evenly
            // spaced rather than the gap all falling below.
            y: Math.round((root.implicitHeight - base.implicitHeight) / 2)
            text: root.text
            color: root.dim
            font.family: Theme.fontUi
            font.pixelSize: root.size
            font.weight: root.weight
            renderType: Text.NativeRendering
        }

        /*
         * The sung part. Clipped from the left, so the edge travels through the
         * word; the text inside keeps its full width, or the glyphs would squash
         * as the clip grew. The clip runs past the word into its trailing space,
         * so the sweep does not stall at the last letter while the gap catches
         * up.
         */
        Item {
            y: base.y
            width: Math.round(root.implicitWidth * Math.max(0, Math.min(1, root.progress)))
            height: base.implicitHeight
            clip: true
            visible: width > 0

            Text {
                width: base.implicitWidth
                text: root.text
                color: root.lit
                font.family: Theme.fontUi
                font.pixelSize: root.size
                font.weight: root.weight
                renderType: Text.NativeRendering
            }
        }
    }
}
