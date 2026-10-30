pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Settings, as a window of its own.
 *
 * A real window rather than a panel on the shell's layer, so the compositor
 * treats it as one: Super+Q closes it, Super+drag moves it, and it takes focus
 * and stacks like an application. It stays open until you say you are done — the
 * close button, Escape, Super+Q, or the gear that opened it.
 *
 * Its minimum and maximum size are the same, which is how a window tells Hyprland
 * it is a dialog: it floats and opens centred instead of being tiled.
 */
FloatingWindow {
    id: root

    readonly property bool open: Shell.openPanel === "settings"
    readonly property int windowWidth: Config.get("settings.width", 960)
    readonly property int windowHeight: Config.get("settings.height", 660)

    visible: root.open
    title: "Stratum Settings"
    color: Theme.surface
    minimumSize: Qt.size(root.windowWidth, root.windowHeight)
    maximumSize: Qt.size(root.windowWidth, root.windowHeight)

    // Closed from outside (Super+Q): the shell's own state has to follow.
    onVisibleChanged: {
        if (!root.visible && root.open)
            Shell.close();
    }

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
        focus: true
        Keys.onEscapePressed: Shell.close()
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
