pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The words of whatever is playing, on the desktop.
 *
 * A window onto the song rather than the one line being sung: what has just
 * gone, what is going now, and what is coming. One line answers "what is this
 * word" and a handful answers "where are we", which is what a glance at a
 * desktop usually wants — and a line arriving at the bottom while another
 * leaves at the top reads as the song moving in a way a single line swapping
 * its text never did.
 *
 * How many lines is a setting, and it sets the type size rather than the
 * widget's: the card on the desktop is whatever size it was dragged to, so
 * asking for more lines makes the words smaller rather than the widget taller.
 *
 * It says what it is doing when it has nothing to show. A lyrics panel that is
 * simply blank is indistinguishable from one that is broken, and the reasons
 * for a blank — nothing playing, still looking, nothing found — want different
 * things from the person reading it.
 */
Item {
    id: root

    property var item: ({})
    property bool live: true

    readonly property bool showHeader: Widgets.option(root.item, "header") !== "hide"
    readonly property string alignment: Widgets.option(root.item, "align")
    readonly property int align: root.alignment === "centre" ? Text.AlignHCenter : Text.AlignLeft

    // How many lines to aim to show. The size follows from it.
    readonly property int lineCount: Math.max(1, parseInt(Widgets.option(root.item, "lines")) || 5)

    readonly property real pad: Math.max(8, root.height * 0.07)
    readonly property real leading: 1.22
    readonly property real listHeight: Math.max(24, root.height - root.pad * 2
        - (root.showHeader ? headerLabel.implicitHeight + root.height * 0.035 : 0))

    // The gap between one line and the next, as a share of the type size.
    readonly property real rowGap: 0.3

    /*
     * Sized so that `lineCount` rows really do fill the room there is.
     *
     * A row costs more than its type size: the font's own line height is about
     * 1.3 of it, the leading multiplies that, and the list puts a gap after it.
     * Leaving the gap out of the sum asked for five lines and fitted four, which
     * is the kind of arithmetic that is only ever wrong in one direction.
     *
     * Capped against the width as well, so a wide, short card does not end up
     * with letters taller than the lines they sit in.
     */
    readonly property real rowPitch: root.leading * 1.3 + root.rowGap
    readonly property real lineSize: Math.max(11,
        Math.min(root.listHeight / (root.lineCount * root.rowPitch), root.width * 0.06))

    readonly property bool singing: Lyrics.any && Lyrics.granularity !== "static"

    Watch {
        service: Lyrics
        live: root.live
    }

    Column {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.height * 0.035

        // What this is, and who answered. The source is worth naming: a sync
        // made by hand and one that only timed the line are not the same thing,
        // and only the label says which is on screen.
        Text {
            id: headerLabel

            width: parent.width
            visible: root.showHeader
            elide: Text.ElideRight
            horizontalAlignment: root.align
            text: {
                if (!Media.available)
                    return "LYRICS";
                if (Lyrics.status === "ready")
                    return `LYRICS · ${Lyrics.provider.replace(/_/g, " ")}${Lyrics.exact ? "" : " · BY LINE"}`;
                return "LYRICS";
            }
            color: Qt.alpha(Theme.fg, 0.35)
            font.family: Theme.fontDot
            font.pixelSize: Math.max(9, Math.min(13, root.height * 0.05))
            font.weight: Font.Bold
            font.letterSpacing: 1.4
            font.variableAxes: ({ "ROND": 100 })
            renderType: Text.NativeRendering
        }

        /*
         * The song, with the line being sung held in the same place and the rest
         * moving past it. The same arrangement as the full-screen view, and for
         * the same reason: a line that wanders down the card until it runs out
         * of room is harder to follow than one that stays put.
         *
         * Never interactive. This is a desktop widget: a stray scroll over the
         * wallpaper should not move the lyrics, and dragging them would leave
         * them somewhere they do not belong.
         */
        ListView {
            id: list

            width: parent.width
            height: root.listHeight
            visible: root.singing
            clip: true
            interactive: false
            model: Lyrics.lines
            spacing: Math.round(root.lineSize * root.rowGap)

            currentIndex: Lyrics.shownIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            // One line of what has just gone, where there is room for it.
            preferredHighlightBegin: root.lineCount > 2 ? Math.round(height * 0.26) : 0
            preferredHighlightEnd: list.preferredHighlightBegin
            highlightMoveDuration: Theme.sheetMs * 1.6
            highlightMoveVelocity: -1
            topMargin: list.preferredHighlightBegin
            bottomMargin: Math.round(height * 0.5)
            cacheBuffer: 600

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                // Sounding now — which is not the same as being the line the
                // view follows, because more than one can be.
                readonly property bool active: Lyrics.isActive(row.index)
                readonly property int distance: row.index - Lyrics.shownIndex
                readonly property bool sung: !row.active && row.distance < 0
                readonly property bool backing: row.modelData?.background === true

                width: list.width
                height: body.implicitHeight

                /*
                 * Falls away with distance, so the lines nearest the top and
                 * bottom edges fade rather than being cut in half by the clip,
                 * and the eye is left in no doubt which line is the live one.
                 */
                opacity: row.active ? 1 : Math.max(0.18, 0.6 - Math.abs(row.distance) * 0.09)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.sheetMs
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }
                }

                LyricLine {
                    id: body

                    width: parent.width
                    line: row.modelData
                    time: row.active ? Lyrics.at : -1
                    done: row.sung
                    // A backing vocal is a second voice under the lead, so it is
                    // drawn as one.
                    size: row.backing ? root.lineSize * 0.8 : root.lineSize
                    weight: row.active ? Font.DemiBold : Font.Medium
                    glow: row.active
                    leading: root.leading
                    lit: Theme.fg
                    dim: Qt.alpha(Theme.fg, 0.26)
                    lift: row.active ? 0.09 : 0
                    swell: row.active ? 0.06 : 0
                    alignRight: row.modelData?.opposite === true
                }
            }
        }

        // Everything else: no music, still looking, nothing found, no key.
        Text {
            width: parent.width
            visible: !root.singing
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
            horizontalAlignment: root.align
            text: {
                if (!Media.available)
                    return "Nothing playing";
                if (Lyrics.status === "loading")
                    return "Looking for the words…";
                if (Lyrics.granularity === "static")
                    return Lyrics.lines.length > 0 ? "Found the words, but nothing to time them to" : "";
                if (Lyrics.error.length > 0)
                    return Lyrics.error;
                if (!Lyrics.haveKey)
                    return "No synced lyrics found. Word timing needs a Spicy Lyrics key — Settings → Lyrics.";
                return "No lyrics for this track";
            }
            color: Qt.alpha(Theme.fg, 0.4)
            font.family: Theme.fontUi
            font.pixelSize: Math.max(12, root.lineSize * 0.62)
            renderType: Text.NativeRendering
        }
    }
}
