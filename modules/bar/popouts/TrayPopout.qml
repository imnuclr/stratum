pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.theme
import qs.utils

/*
 * A tray item, opened up: what it is, what it says about itself, and its menu
 * laid out in the panel rather than as a separate native menu. Submenus show one
 * level deep, indented under their parent.
 */
Item {
    id: root

    readonly property var item: Popouts.trayItem
    readonly property string name: root.item?.tooltipTitle || root.item?.title || root.item?.id || "app"
    // Tooltips may carry markup; the plain text is what fits here.
    readonly property string about: String(root.item?.tooltipDescription ?? "").replace(/<[^>]*>/g, "").trim()

    implicitWidth: 268
    implicitHeight: body.implicitHeight

    function run(entry) {
        Popouts.hide();
        entry.triggered();
    }

    Column {
        id: body

        width: parent.width
        spacing: Theme.space(2)

        Row {
            width: parent.width
            spacing: Theme.space(3)

            Rectangle {
                width: 40
                height: 40
                radius: 12
                color: Theme.surfaceTop

                Image {
                    anchors.centerIn: parent
                    width: 24
                    height: 24
                    source: root.item ? Icons.trayIcon(root.item.icon) : ""
                    sourceSize.width: 48
                    sourceSize.height: 48
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 40 - Theme.space(3)
                spacing: 2

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.name
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                Text {
                    width: parent.width
                    visible: text.length > 0
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: root.about.length > 0 ? root.about : (root.item?.hasMenu ? "" : "click to open")
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.line
            visible: menuList.count > 0
        }

        QsMenuOpener {
            id: opener

            menu: root.item?.menu ?? null
        }

        Column {
            width: parent.width
            spacing: 0

            Repeater {
                id: menuList

                model: opener.children

                Column {
                    id: entry

                    required property var modelData

                    // A submenu is a dropdown, folded until it is clicked.
                    property bool open: false

                    width: parent.width

                    MenuLine {
                        width: parent.width
                        entry: entry.modelData
                        expanded: entry.open
                        onPicked: e => root.run(e)
                        onToggled: entry.open = !entry.open
                    }

                    QsMenuOpener {
                        id: sub

                        menu: entry.modelData.hasChildren ? entry.modelData : null
                    }

                    Item {
                        width: parent.width
                        height: entry.open ? subList.implicitHeight : 0
                        clip: true
                        visible: height > 0

                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.standard * 1.6
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.smooth
                            }
                        }

                        Column {
                            id: subList

                            width: parent.width

                            Repeater {
                                model: entry.modelData.hasChildren ? sub.children : []

                                MenuLine {
                                    required property var modelData

                                    width: entry.width
                                    indent: Theme.space(4)
                                    entry: modelData
                                    onPicked: e => root.run(e)
                                }
                            }
                        }
                    }
                }
            }
        }

        // Nothing to list: the item's own action is the only thing on offer.
        LinkButton {
            visible: menuList.count === 0
            text: "open"
            onClicked: {
                Popouts.hide();
                root.item?.activate();
            }
        }
    }

    component MenuLine: Item {
        id: line

        property var entry: null
        property real indent: 0
        property bool expanded: false

        signal picked(var e)
        signal toggled

        readonly property bool separator: !!line.entry?.isSeparator
        readonly property bool parentLine: !!line.entry?.hasChildren
        readonly property bool usable: !line.separator && (line.entry?.enabled ?? true)
        readonly property bool ticked: (line.entry?.buttonType ?? 0) !== 0 && line.entry?.checkState === Qt.Checked

        height: line.separator ? Theme.space(2) + 1 : 32

        Rectangle {
            visible: line.separator
            anchors.verticalCenter: parent.verticalCenter
            x: line.indent
            width: parent.width - line.indent
            height: 1
            color: Theme.line
        }

        Rectangle {
            visible: !line.separator
            anchors.fill: parent
            anchors.leftMargin: line.indent - Theme.space(1)
            anchors.rightMargin: -Theme.space(1)
            radius: Theme.rInner - 4
            color: lineHover.hovered && line.usable ? Theme.surfaceTop : "transparent"
        }

        Glyph {
            id: tick

            visible: !line.separator
            x: line.indent
            anchors.verticalCenter: parent.verticalCenter
            name: "check"
            size: 14
            color: Theme.fg
            opacity: line.ticked ? 1 : 0
        }

        Text {
            visible: !line.separator
            anchors.left: tick.right
            anchors.leftMargin: Theme.space(2)
            anchors.right: chevron.left
            anchors.rightMargin: Theme.space(1)
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            // Mnemonic underscores are for keyboard menus.
            text: String(line.entry?.text ?? "").replace(/_(?!_)/g, "")
            color: line.usable ? Theme.fg : Theme.fgFaint
            font.family: Theme.fontUi
            font.pixelSize: 13
            renderType: Text.NativeRendering
        }

        Glyph {
            id: chevron

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: line.parentLine
            width: visible ? 14 : 0
            name: "chevron-down"
            size: 14
            color: Theme.fgDim
            rotation: line.expanded ? 0 : -90

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.standard * 1.6
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.smooth
                }
            }
        }

        HoverHandler {
            id: lineHover

            enabled: line.usable
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            enabled: line.usable
            onTapped: line.parentLine ? line.toggled() : line.picked(line.entry)
        }
    }
}
