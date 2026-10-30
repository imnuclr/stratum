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
    readonly property int windowWidth: Config.get("settings.width", 1180)
    readonly property int windowHeight: Config.get("settings.height", 780)

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

    readonly property int railWidth: 216

    /*
     * Every page, in the order the sidebar lists them. `words` is what the
     * search box matches besides the name, so "volume" finds Sound.
     */
    readonly property var pages: [
        { label: "wallpaper", name: "Wallpaper", icon: "image", group: "personal", words: "background picture photo", component: wallpaperPage },
        { label: "appearance", name: "Appearance", icon: "contrast", group: "personal", words: "dark light theme colour color accent clock 24 hour", component: appearancePage },
        { label: "motion", name: "Motion", icon: "motion", group: "personal", words: "animation speed reduce fade", component: motionPage },
        { label: "bar", name: "Bar", icon: "sidebar", group: "desktop", words: "panel edge column strip workspaces", component: barPage },
        { label: "widgets", name: "Widgets", icon: "grid", group: "desktop", words: "desktop clock weather", component: widgetsPage },
        { label: "launcher", name: "Launcher", icon: "search", group: "desktop", words: "spotlight search apps files calculator web", component: launcherPage },
        { label: "notifications", name: "Notifications", icon: "bell", group: "desktop", words: "toasts do not disturb dnd", component: notificationsPage },
        { label: "display", name: "Display", icon: "brightness", group: "system", words: "brightness night light screen", component: displayPage },
        { label: "sound", name: "Sound", icon: "volume-2", group: "system", words: "volume audio speakers headphones microphone mic output input", component: soundPage },
        { label: "network", name: "Network", icon: "wifi", group: "system", words: "wifi wi-fi ethernet wired vpn airplane internet", component: networkPage },
        { label: "bluetooth", name: "Bluetooth", icon: "bluetooth", group: "system", words: "devices pair headphones", component: bluetoothPage },
        { label: "power", name: "Power", icon: "bolt", group: "system", words: "battery profile eco performance sleep caffeine awake", component: powerPage },
        { label: "monitors", name: "Monitors", icon: "monitor", group: "system", words: "displays screens arrange", component: monitorsPage },
        { label: "keybinds", name: "Keybinds", icon: "keyboard", group: "system", words: "keyboard shortcuts keys hotkeys", component: keybindsPage },
        { label: "about", name: "About", icon: "info", group: "stratum", words: "version system computer hardware", component: aboutPage },
        { label: "advanced", name: "Advanced", icon: "sliders", group: "stratum", words: "debug config files folder", component: advancedPage }
    ]

    readonly property var groups: ["personal", "desktop", "system", "stratum"]

    // What the sidebar's search box holds.
    property string filter: ""

    function matches(p) {
        const q = root.filter.trim().toLowerCase();
        if (q.length === 0)
            return true;
        return `${p.label} ${p.words}`.toLowerCase().split(/\s+/).some(w => w.startsWith(q))
            || p.name.toLowerCase().includes(q);
    }

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

        TextField {
            id: search

            anchors.top: parent.top
            anchors.left: parent.left
            width: root.railWidth
            height: 36
            radius: height / 2
            placeholder: "search settings"
            onTextChanged: root.filter = text
            onAccepted: {
                const hit = root.pages.find(p => root.matches(p));
                if (hit)
                    Shell.settingsPage = hit.label;
            }

            Glyph {
                anchors.right: parent.right
                anchors.rightMargin: Theme.space(3)
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                size: 14
                color: Theme.fgDim
            }
        }

        Flickable {
            id: railScroll

            anchors.top: search.bottom
            anchors.topMargin: Theme.space(3)
            anchors.bottom: closer.top
            anchors.bottomMargin: Theme.space(3)
            anchors.left: parent.left
            width: root.railWidth
            contentHeight: rail.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: rail

                width: root.railWidth
                spacing: Theme.space(3)

                Repeater {
                    model: root.groups

                    Column {
                        id: group

                        required property string modelData

                        readonly property var members: root.pages.filter(p => p.group === group.modelData && root.matches(p))

                        width: rail.width
                        spacing: 2
                        visible: group.members.length > 0

                        SectionLabel {
                            leftPadding: Theme.space(3)
                            bottomPadding: Theme.space(1)
                            text: group.modelData
                            color: Theme.fgFaint
                        }

                        Repeater {
                            model: group.members

                            Rectangle {
                                id: item

                                required property var modelData

                                readonly property bool chosen: item.modelData.label === root.pages[root.page].label

                                width: rail.width
                                height: 40
                                radius: Theme.rInner
                                // The chosen page is inverted, like every other "on" in the shell.
                                color: item.chosen ? Theme.fg : (hover.hovered ? Theme.surfaceTop : "transparent")

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.micro
                                    }
                                }

                                Rectangle {
                                    id: chip

                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.space(2)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28
                                    height: 28
                                    radius: 8
                                    color: item.chosen ? Theme.bg : Theme.surfaceTop

                                    Glyph {
                                        anchors.centerIn: parent
                                        name: item.modelData.icon
                                        size: 16
                                        color: Theme.fg
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: chip.right
                                    anchors.leftMargin: Theme.space(3)
                                    text: item.modelData.name
                                    color: item.chosen ? Theme.bg : Theme.fgBright
                                    font.family: Theme.fontUi
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                    renderType: Text.NativeRendering
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
                }

                Text {
                    visible: !root.pages.some(p => root.matches(p))
                    leftPadding: Theme.space(3)
                    text: "nothing matches"
                    color: Theme.fgFaint
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
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
        id: barPage

        BarPage {}
    }

    Component {
        id: monitorsPage

        MonitorsPage {}
    }

    Component {
        id: widgetsPage

        WidgetsPage {}
    }

    Component {
        id: keybindsPage

        KeybindsPage {}
    }

    Component {
        id: advancedPage

        AdvancedPage {}
    }
    Component {
        id: motionPage

        MotionPage {}
    }

    Component {
        id: launcherPage

        LauncherPage {}
    }

    Component {
        id: displayPage

        DisplayPage {}
    }

    Component {
        id: soundPage

        SoundPage {}
    }

    Component {
        id: networkPage

        NetworkPage {}
    }

    Component {
        id: bluetoothPage

        BluetoothPage {}
    }

    Component {
        id: powerPage

        PowerPage {}
    }

    Component {
        id: aboutPage

        AboutPage {}
    }
}
