import QtQuick
import qs.theme

/*
 * The shell's surface primitive. `active` inverts the fill — a white tile is on.
 * That inversion is the only state language the design uses, so it lives here
 * rather than in each module.
 */
Rectangle {
    id: root

    property bool active: false
    property bool hovered: false
    property int level: 1

    // Floating surfaces sit over an arbitrary wallpaper, so they carry a stronger
    // hairline than tiles nested inside a panel. Verified against a dark wallpaper,
    // where the 7% line left the bar invisible.
    property bool floating: false

    readonly property color contentColor: active ? Theme.bg : Theme.fg

    radius: Theme.rTile
    color: {
        if (active)
            return Theme.fg;
        if (hovered)
            return Theme.surfaceTop;
        return level === 0 ? Theme.surface : Theme.surfaceHi;
    }
    border.width: active ? 0 : 1
    border.color: floating ? Theme.outline : Theme.line

    Behavior on color {
        ColorAnimation {
            duration: Theme.standard
            easing.bezierCurve: Theme.enterEasing
            easing.type: Easing.Bezier
        }
    }
}
