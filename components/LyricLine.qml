import QtQuick
import qs.theme

/*
 * One line of a lyric, as its words.
 *
 * A Flow rather than a single Text, because every word has to be positioned in
 * order to be swept separately. The space between words is carried by the word
 * before it rather than by the Flow's spacing: a syllable sync splits "even"
 * into "e" and "ven", which have to sit together with no gap, and a uniform
 * spacing cannot tell the difference between those and two words.
 *
 * A line with no words draws as one piece and lights whole. That is both the
 * case where there is no timing at all — plain lyrics — and the case where the
 * source timed the line but not the words inside it, which is most of them. The
 * shell used to guess the words' places and sweep them anyway; a sweep says
 * where in the line the voice is, and a guess saying that reads as the lyrics
 * being out of time rather than as an estimate.
 */
Flow {
    id: root

    // One of Lyrics.lines.
    property var line: null
    // Seconds into the track.
    property real time: 0
    property real size: 22
    property int weight: Font.DemiBold
    property color dim: Theme.fgFaint
    property color lit: Theme.fgBright
    property real lift: 0.1
    property real swell: 0.06
    property bool glow: true
    // Everything lit regardless of the clock, for a line shown as read rather
    // than as being sung.
    property bool done: false
    // Leading, as a multiple of the type size. A wrapped lyric needs more air
    // between its two halves than a paragraph does, because each half is read
    // as its own line.
    property real leading: 1.28
    /*
     * The second voice of a duet, which its source marks to be set against the
     * first. Only the whole-line form honours it: a Flow lays its items out in
     * one direction and turning it round to reach the right margin would print
     * the words of the line backwards, which is worse than the line sitting on
     * the wrong side.
     */
    property bool alignRight: false

    readonly property var words: root.line?.words ?? []
    readonly property string plain: root.line?.text ?? ""

    // Nothing to sweep with, so the line is lit or it is not.
    readonly property bool whole: root.words.length === 0
    /*
     * Whether a whole line is being sung now. Callers hand a real `time` only to
     * the line that is current and -1 to the rest, which is the same thing they
     * do for the swept case — so no caller has to learn a second rule for a
     * source that happens to be line-timed.
     */
    readonly property bool sounding: root.done
        || (root.time >= 0 && !!root.line && root.time >= root.line.start)

    /*
     * The height of one row of this line, leading included.
     *
     * Callers need it to reserve room: a lyrics panel that sizes itself to the
     * line showing grows and shrinks every time one wraps, and a caller that
     * guesses the row height from the type size gets it wrong by whatever the
     * font's line height adds — which is enough to clip a descender off the
     * second row and leave the next line sitting on top of it.
     *
     * Measured from a hidden Text in the same font, so it is the same number
     * the words themselves are laid out with. Hidden, so the Flow does not
     * place it: positioners skip invisible children.
     */
    readonly property real rowHeight: Math.round(rowProbe.implicitHeight * root.leading)

    Text {
        id: rowProbe

        visible: false
        text: "Ag"
        font.family: Theme.fontUi
        font.pixelSize: root.size
        font.weight: root.weight
        renderType: Text.NativeRendering
    }

    spacing: 0

    function progressOf(word, index) {
        if (root.done)
            return 1;
        if (!word || !(word.end > word.start))
            return root.time >= word?.start ? 1 : 0;
        return Math.max(0, Math.min(1, (root.time - word.start) / (word.end - word.start)));
    }

    /*
     * A word is followed by a space unless it runs into the next piece. The last
     * one on a line carries no trailing gap, so a line ending mid-wrap does not
     * leave a hanging space that shifts it off its margin.
     */
    function spaceAfter(index) {
        return index < root.words.length - 1 && !root.words[index].joinNext;
    }

    Repeater {
        model: root.words

        LyricWord {
            required property var modelData
            required property int index

            text: modelData.text
            gapAfter: root.spaceAfter(index)
            progress: root.progressOf(modelData, index)
            size: root.size
            weight: root.weight
            dim: root.dim
            lit: root.lit
            lift: root.lift
            swell: root.swell
            glow: root.glow
            leading: root.leading
        }
    }

    /*
     * The line as one piece. It lights rather than sweeps, and it fades up
     * rather than switching: the only thing happening on screen at that moment
     * is this line becoming the one being sung, so it is worth a quarter of a
     * second of it.
     */
    Text {
        visible: root.whole && root.plain.length > 0
        width: root.width
        wrapMode: Text.WordWrap
        lineHeight: root.leading
        lineHeightMode: Text.ProportionalHeight
        horizontalAlignment: root.alignRight ? Text.AlignRight : Text.AlignLeft
        text: root.plain
        color: root.sounding ? root.lit : root.dim
        font.family: Theme.fontUi
        font.pixelSize: root.size
        font.weight: root.weight
        renderType: Text.NativeRendering

        Behavior on color {
            ColorAnimation {
                duration: Theme.sheetMs
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.soft
            }
        }
    }
}
