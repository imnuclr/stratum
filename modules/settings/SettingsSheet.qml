pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Settings, as a panel in the middle of the screen.
 *
 * Reached by choosing it, not by pointing at a corner, so it neither grows out of
 * an edge nor closes when the pointer leaves: you are expected to be reading it
 * and clicking around inside it, and to say when you are done — the close button,
 * Escape, or the gear that opened it.
 */
Sheet {
    id: root

    readonly property int page: Math.max(0, root.pages.findIndex(p => p.label === Shell.settingsPage))
    // What is on screen. Follows `page` a moment later, once the old page has
    // faded out, so the swap happens while nothing is visible.
    property int shown: 0

    Component.onCompleted: root.shown = root.page

    // Pages are built only while the panel is up, and for the length of its exit.
    // The wallpaper grid is the reason: it should not hold a folder of decoded
    // images, or decode them, on behalf of a menu nobody opened.
    property bool alive: false

    readonly property int railWidth: 188

    readonly property var pages: [
        { label: "wallpaper", component: wallpaperPage },
        { label: "appearance", component: appearancePage },
        { label: "notifications", component: notificationsPage },
        { label: "advanced", component: advancedPage }
    ]

    name: "settings"
    centered: true
    travel: 28
    slideSign: 1
    sheetWidth: Math.min(Config.get("settings.width", 960), monitor.width - barOffset - Theme.space(6))
    sheetHeight: Math.min(availableHeight, Config.get("settings.height", 660))

    onOpenChanged: {
        if (open) {
            lifetime.stop();
            root.alive = true;
        } else {
            lifetime.restart();
        }
    }

    onPageChanged: swap.restart()

    Timer {
        id: lifetime

        interval: Theme.sheetMs + 100
        onTriggered: root.alive = false
    }

    Item {
        anchors.fill: parent
        anchors.margins: Theme.space(5)

        Column {
            id: rail

            width: root.railWidth
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            spacing: Theme.space(1)

            SectionLabel {
                text: "settings"
                bottomPadding: Theme.space(3)
            }

            Repeater {
                model: root.pages

                Rectangle {
                    id: item

                    required property int index
                    required property var modelData

                    readonly property bool chosen: item.index === root.page

                    width: rail.width
                    height: 44
                    radius: height / 2
                    // The chosen page is inverted, like every other "on" in the shell.
                    color: item.chosen ? Theme.fg : (hover.hovered ? Theme.surfaceTop : "transparent")

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.micro
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.space(4)
                        text: item.modelData.label
                        color: item.chosen ? Theme.bg : Theme.fgBright
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.micro
                            }
                        }
                    }

                    HoverHandler {
                        id: hover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: Shell.settingsPage = item.modelData.label
                    }
                }
            }
        }


        Rectangle {
            id: closer

            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: root.railWidth
            height: 40
            radius: height / 2
            color: closeHover.hovered ? Theme.accent : Theme.surfaceHi

            Behavior on color {
                ColorAnimation {
                    duration: Theme.micro
                }
            }

            Row {
                anchors.centerIn: parent
                spacing: Theme.space(2)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "close"
                    size: 14
                    color: closeHover.hovered ? Theme.bg : Theme.fg
                }

                SectionLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "close"
                    color: closeHover.hovered ? Theme.bg : Theme.fgBright
                }
            }

            HoverHandler {
                id: closeHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: Shell.close()
            }
        }

        Rectangle {
            id: rule

            anchors.left: rail.right
            anchors.leftMargin: Theme.space(5)
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: Theme.line
        }

        Item {
            id: area

            anchors.left: rule.right
            anchors.leftMargin: Theme.space(5)
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            Loader {
                id: pageLoader

                width: area.width
                height: area.height
                active: root.alive
                sourceComponent: root.pages[root.shown].component
                opacity: 1

                // Out fast, in slower, and a short rise as it arrives: the new page
                // settles into place instead of replacing the old one.
                SequentialAnimation {
                    id: swap

                    NumberAnimation {
                        target: pageLoader
                        property: "opacity"
                        to: 0
                        duration: Theme.micro
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.soft
                    }

                    ScriptAction {
                        script: {
                            root.shown = root.page;
                            pageLoader.y = 8;
                        }
                    }

                    ParallelAnimation {
                        NumberAnimation {
                            target: pageLoader
                            property: "opacity"
                            to: 1
                            duration: Theme.sheetMs * 0.7
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.soft
                        }

                        NumberAnimation {
                            target: pageLoader
                            property: "y"
                            to: 0
                            duration: Theme.sheetMs * 0.7
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.soft
                        }
                    }
                }
            }
        }
    }

    Component {
        id: wallpaperPage

        WallpaperPage {}
    }

    Component {
        id: appearancePage

        AppearancePage {}
    }

    Component {
        id: notificationsPage

        NotificationsPage {}
    }

    Component {
        id: advancedPage

        AdvancedPage {}
    }
}
