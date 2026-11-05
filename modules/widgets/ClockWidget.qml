import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The time in large dot-matrix numerals, with the date beneath.
 *
 * The numerals are as large as the widget allows: sized from a measured copy of
 * the same text, so they fill the width however the font's proportions work out.
 */
Item {
    id: root

    property var item: ({})
    property bool live: true

    // "auto" follows Settings → Appearance → Clock.
    readonly property string hours: Widgets.option(root.item, "hours")
    readonly property bool twelve: root.hours === "12h" || (root.hours !== "24h" && Time.twelveHour)
    readonly property bool showDate: Widgets.option(root.item, "date") !== "hide"
    readonly property bool showSeconds: Widgets.option(root.item, "seconds") === "show"

    /*
     * Seconds cost a repaint a second on the desktop layer, so the clock only
     * asks for them while it is actually being looked at — the same discipline
     * the polling widgets follow. `live` comes from the canvas, which knows when
     * its desktop is covered, and an energy saver or game mode drops them too.
     */
    readonly property bool wantSeconds: root.showSeconds && root.live
        && !Power.saving("widgets") && !GameMode.on
    property bool heldSeconds: false

    function syncSeconds() {
        if (root.wantSeconds === root.heldSeconds)
            return;
        if (root.wantSeconds)
            Time.useSeconds();
        else
            Time.releaseSeconds();
        root.heldSeconds = root.wantSeconds;
    }

    onWantSecondsChanged: root.syncSeconds()
    Component.onCompleted: root.syncSeconds()
    Component.onDestruction: if (root.heldSeconds) Time.releaseSeconds()

    // The width one pixel of numeral size takes, measured rather than assumed.
    DotText {
        id: probe

        visible: false
        text: root.twelve ? "12:54" : "16:54"
        size: 100
        plain: true
    }

    // The seconds have to be in the sum too, or the numerals are sized for the
    // time alone and the seconds are drawn past the widget's edge and clipped.
    DotText {
        id: secsProbe

        visible: false
        text: "00"
        size: 100
        plain: true
    }

    readonly property real unit: probe.implicitWidth > 0 ? probe.implicitWidth / 100 : 3.2
    readonly property real unitSecs: secsProbe.implicitWidth > 0 ? secsProbe.implicitWidth / 100 : 1.3
    // Width one pixel of numeral size costs, counting the gap and the seconds.
    readonly property real span: root.unit + (root.showSeconds ? 0.12 + 0.34 * root.unitSecs : 0)
    readonly property real numeral: Math.max(24, Math.min(root.height * (root.showDate ? 0.7 : 0.9), root.width / root.span))

    readonly property string time: Time.clockOf(Time.now, root.twelve)
    readonly property string secs: Qt.formatDateTime(Time.now, "ss")

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.numeral * 0.08)

        Row {
            spacing: Math.round(root.numeral * 0.12)

            /*
             * The time, with a halo of the background colour behind it.
             *
             * The canvas already picks the ink from how bright the wallpaper is
             * under the whole widget, but numerals this large span more than one
             * kind of ground: a digit can sit half on bright sky and half on a
             * dark tree, and whichever ink was chosen loses half the glyph. Four
             * offset copies in the ground colour give every dot its own edge, so
             * the time reads wherever it happens to fall.
             *
             * Offsets rather than a blur: MultiEffect is what took the shell down
             * on the lock surface, and a handful of extra Text items is a cheaper
             * and more predictable way to buy an outline. The canvas inverts the
             * whole widget when it flips the ink, which inverts halo and numerals
             * together and so preserves the contrast between them.
             */
            Item {
                id: face

                readonly property real spread: Math.max(1, Math.round(root.numeral * 0.014))

                implicitWidth: numerals.implicitWidth
                implicitHeight: numerals.implicitHeight

                Repeater {
                    model: [[-1, 0], [1, 0], [0, -1], [0, 1]]

                    DotText {
                        required property var modelData

                        x: modelData[0] * face.spread
                        y: modelData[1] * face.spread
                        text: root.time
                        size: root.numeral
                        color: Theme.bg
                        opacity: 0.55
                        plain: true
                    }
                }

                /*
                 * Not plain: the dot-matrix cascade is the shell's signature
                 * transition, and the clock — the largest run of numerals on the
                 * desktop — was the one place it had been switched off, so a
                 * minute passing was a silent swap. DotText re-reveals only the
                 * characters that changed, so a tick animates the digit that
                 * moved rather than the whole time.
                 */
                DotText {
                    id: numerals

                    text: root.time
                    size: root.numeral
                }
            }

            // Trailing, smaller and dimmer: the seconds are there to show the
            // clock is live, not to be read at a glance.
            DotText {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Math.round(root.numeral * 0.1)
                visible: root.showSeconds
                text: root.secs
                size: Math.round(root.numeral * 0.34)
                color: Theme.fgBright
            }
        }

        // Sized to the numerals and set in from their left edge by the same
        // margin the first digit has, so it reads as the clock's own caption
        // rather than a label left lying underneath it.
        Text {
            visible: root.showDate
            leftPadding: root.numeral * 0.06
            text: `${Time.format("dddd · d MMMM")} · week ${Time.weekNumber()}`.toUpperCase()
            color: Theme.fgBright
            font.family: Theme.fontUi
            font.pixelSize: Math.max(11, root.numeral * 0.06)
            font.weight: Font.Medium
            font.letterSpacing: Math.max(1.4, root.numeral * 0.012)
            renderType: Text.NativeRendering
        }
    }
}
