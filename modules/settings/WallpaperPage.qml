pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

/*
 * Picking a wallpaper: what is showing, which display it is for, and the rest of
 * the folder to choose from.
 */
Item {
    id: page

    // Empty means the whole desktop; otherwise one monitor by name.
    property string target: ""

    readonly property var names: Quickshell.screens.map(s => s.name)
    readonly property string previewMonitor: page.target.length > 0 ? page.target : (page.names[0] ?? "")
    readonly property string showing: Wallpaper.forMonitor(page.previewMonitor)

    function baseName(path) {
        return path ? path.slice(path.lastIndexOf("/") + 1) : "";
    }

    Column {
        id: top

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Theme.space(3)

        Item {
            width: parent.width
            height: heading.implicitHeight

            SectionLabel {
                id: heading

                text: "wallpaper"
            }

            SectionLabel {
                anchors.right: parent.right
                text: `${Wallpaper.entries.length} images`
                dim: true
            }
        }

        Segmented {
            // Only offered when there is more than one display to choose between.
            visible: page.names.length > 1
            height: visible ? implicitHeight : 0
            model: ["all displays"].concat(page.names)
            current: page.target.length === 0 ? 0 : page.names.indexOf(page.target) + 1
            onPicked: index => page.target = index === 0 ? "" : page.names[index - 1]
        }

        ClippingRectangle {
            width: parent.width
            height: 172
            radius: Theme.rInner
            color: Theme.surfaceHi

            Image {
                anchors.fill: parent
                source: page.showing.length > 0 ? `file://${page.showing}` : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 900
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }
                }
            }

            // Name of the file on a scrim, so it reads over any image.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 52
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: "#B3000000" }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space(3)
                text: page.baseName(page.showing)
                color: "#FFFFFF"
                font.family: Theme.fontUi
                font.pixelSize: 12
                font.weight: Font.Medium
                renderType: Text.NativeRendering
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.space(2)
                spacing: Theme.space(1)

                IconButton {
                    icon: "skip-back"
                    size: 32
                    onClicked: Wallpaper.cycle(-1, page.target)
                }

                ActionButton {
                    text: "shuffle"
                    width: 84
                    height: 32
                    onClicked: Wallpaper.random(page.target)
                }

                IconButton {
                    icon: "skip-forward"
                    size: 32
                    onClicked: Wallpaper.cycle(1, page.target)
                }
            }
        }
    }

    GridView {
        id: grid

        readonly property int columns: Math.max(3, Math.floor(width / 150))

        anchors.top: top.bottom
        anchors.topMargin: Theme.space(3)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        cellWidth: Math.floor(width / columns)
        cellHeight: Math.round(cellWidth * 0.6)
        // Only what is on screen is decoded; the rest of the folder costs nothing
        // until it is scrolled to.
        cacheBuffer: cellHeight * 2

        model: Wallpaper.entries

        delegate: Item {
            id: cell

            required property string modelData

            readonly property bool chosen: cell.modelData === page.showing

            width: grid.cellWidth
            height: grid.cellHeight

            ClippingRectangle {
                id: thumb

                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.rInner
                color: Theme.surfaceHi
                // Lifts under the pointer, so the grid answers before it is clicked.
                scale: press.pressed ? 0.97 : (hover.hovered ? 1.03 : 1)

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.gentle
                    }
                }

                Image {
                    anchors.fill: parent
                    source: `file://${cell.modelData}`
                    fillMode: Image.PreserveAspectCrop
                    // Decoded at thumbnail size, not full: these are 4K images and
                    // a grid of them would otherwise sit in memory at full size.
                    sourceSize.width: 320
                    sourceSize.height: 200
                    asynchronous: true
                    cache: true
                    opacity: status === Image.Ready ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.standard
                        }
                    }
                }

                // The chosen one gets the accent: a ring, not a fill, so the
                // picture stays the thing being looked at.
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: cell.chosen ? 2 : 0
                    border.color: Theme.accent
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    id: press

                    onTapped: Wallpaper.set(cell.modelData, page.target)
                }
            }
        }

        // A scroll indicator: this is a long list and nothing otherwise says so.
        Rectangle {
            anchors.right: parent.right
            width: 3
            radius: 1.5
            color: Theme.fgFaint
            opacity: grid.moving || grid.flicking ? 1 : 0.5
            visible: grid.visibleArea.heightRatio < 1
            y: grid.visibleArea.yPosition * grid.height
            height: Math.max(24, grid.visibleArea.heightRatio * grid.height)
        }
    }
}
