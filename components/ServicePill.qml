import QtQuick
import qs.theme

/*
 * The wide connection toggles at the head of the control centre: a filled icon
 * disc, the service name with its current state beneath, and a chevron for the
 * detail panel. The disc inverts with the state so the pill reads as on or off
 * from the shape alone, without reading the label.
 */
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string detail: ""
    property bool active: false
    // Whether this pill's list is the one showing, so the chevron points at
    // what it will do rather than always down.
    property bool open: false

    signal toggled
    signal expanded

    implicitHeight: 62

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: hover.hovered ? Theme.surfaceTop : Theme.surfaceHi

        Behavior on color {
            ColorAnimation {
                duration: Theme.micro
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    Rectangle {
        id: disc

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
        width: 54
        height: 54
        radius: width / 2
        color: root.active ? Theme.fg : Theme.bg

        Behavior on color {
            ColorAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }

        Glyph {
            anchors.centerIn: parent
            name: root.icon
            size: 21
            stroke: 1.8
            color: root.active ? Theme.bg : Theme.fgBright
        }

        TapHandler {
            onTapped: root.toggled()
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: disc.right
        anchors.leftMargin: Theme.space(3)
        anchors.right: chevron.left
        anchors.rightMargin: Theme.space(2)
        spacing: 1

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 15
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
        }

        SectionLabel {
            width: parent.width
            elide: Text.ElideRight
            text: root.detail
        }
    }

    Glyph {
        id: chevron

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.space(3)
        name: "chevron-down"
        size: 15
        color: root.open ? Theme.fgBright : Theme.fgFaint
        rotation: root.open ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: Theme.standard
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    HoverHandler {
        id: hover
    }

    /*
     * Everything but the disc opens the list.
     *
     * This used to be a TapHandler on the pill itself, with the disc's own
     * handler inside it. Two handlers over the same point both see the tap, so
     * a press on the disc could turn the service off *and* open its list — and
     * the list arriving over a service that had just been switched off is a
     * confusing way to be told either thing happened. Separate areas mean one
     * press does one thing.
     */
    Item {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: disc.right
        anchors.right: parent.right

        TapHandler {
            onTapped: root.expanded()
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
    }
}
