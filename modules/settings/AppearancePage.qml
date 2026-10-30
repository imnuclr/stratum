pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Light or dark, and the one colour the shell uses for emphasis.
 *
 * The accent is deliberately a single choice. The design is monochrome with one
 * red; offering a palette per surface would be offering to undo that. Everything
 * that is red follows this, and nothing else is coloured.
 */
SettingsPage {
    id: page

    Component.onCompleted: WallColours.find()

    icon: "contrast"
    title: "Appearance"
    detail: "Light or dark, colours from your wallpaper, and the accent."

    // The preset's own accent, which the first swatch stands for.
    readonly property string presetAccent: Theme.preset?.color?.accent ?? "#E5252B"
    readonly property string chosen: Theme.user?.color?.accent ?? ""

    readonly property var swatches: [
        "",
        "#FF6A1A", "#FFB800", "#3DDC84", "#22D3EE", "#3B82F6", "#8B5CF6", "#EC4899", "#F4F4F5"
    ]

    SettingCard {
        SettingRow {
            width: parent.width
            title: "Mode"
            detail: "Dark or light. Follows through to GTK apps."

            Segmented {
                model: ["dark", "light"]
                current: Toggles.dark ? 0 : 1
                onPicked: index => Toggles.setDark(index === 0)
            }
        }

        SettingRow {
            width: parent.width
            title: "Colours from wallpaper"
            detail: !WallColours.available
                ? (WallColours.searched === "searching" ? "Looking for matugen…"
                    : `matugen wasn't found (${WallColours.searched}). If it is installed, set its path: stratum ipc config set theme.matugen '"/path/to/matugen"'`)
                : (WallColours.error.length > 0 ? WallColours.error
                    : `Accent follows the picture; full also tints the surfaces. Using ${WallColours.binary}.`)

            Segmented {
                model: ["off", "accent", "full"]
                current: Math.max(0, ["off", "accent", "full"].indexOf(WallColours.mode))
                onPicked: index => Config.set("theme.fromWallpaper", ["off", "accent", "full"][index])
            }
        }

        SettingRow {
            width: parent.width
            title: "Accent"
            detail: "The one colour used for emphasis: the play button, the chosen item, the unread count."

            Flow {
                width: 9 * 40
                spacing: 6

                Repeater {
                    model: page.swatches

                    Rectangle {
                        id: swatch

                        required property string modelData

                        readonly property color colour: swatch.modelData.length > 0 ? swatch.modelData : page.presetAccent
                        readonly property bool selected: swatch.modelData === page.chosen

                        width: 34
                        height: 34
                        radius: width / 2
                        color: swatch.colour
                        scale: tap.pressed ? 0.9 : (hover.hovered ? 1.1 : 1)

                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.standard
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.gentle
                            }
                        }

                        // Chosen is a ring standing off the swatch, not a change to
                        // the swatch itself, so its colour stays honest.
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 8
                            height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Theme.fg
                            opacity: swatch.selected ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.standard
                                    easing.type: Easing.Bezier
                                    easing.bezierCurve: Theme.smooth
                                }
                            }
                        }

                        HoverHandler {
                            id: hover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            id: tap

                            onTapped: {
                                if (swatch.modelData.length === 0)
                                    Theme.clearUser("color.accent");
                                else
                                    Theme.setUser("color.accent", swatch.modelData);
                            }
                        }
                    }
                }
            }
        }
        // Any colour at all: typed as hex, or picked off the hue strip.
        SettingRow {
            width: parent.width
            title: "Custom colour"
            detail: "Type a hex code, or click along the strip."

            Row {
                spacing: Theme.space(3)

                Rectangle {
                    id: hues

                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    height: 22
                    radius: height / 2

                    gradient: Gradient {
                        orientation: Gradient.Horizontal

                        GradientStop { position: 0.0; color: Qt.hsla(0.0, 0.8, 0.55, 1) }
                        GradientStop { position: 0.17; color: Qt.hsla(0.17, 0.8, 0.55, 1) }
                        GradientStop { position: 0.33; color: Qt.hsla(0.33, 0.8, 0.55, 1) }
                        GradientStop { position: 0.5; color: Qt.hsla(0.5, 0.8, 0.55, 1) }
                        GradientStop { position: 0.67; color: Qt.hsla(0.67, 0.8, 0.55, 1) }
                        GradientStop { position: 0.83; color: Qt.hsla(0.83, 0.8, 0.55, 1) }
                        GradientStop { position: 1.0; color: Qt.hsla(1.0, 0.8, 0.55, 1) }
                    }

                    // Where the chosen colour sits on the strip.
                    Rectangle {
                        readonly property real hue: Math.max(0, Theme.accent.hslHue)

                        x: hue * (hues.width - width)
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14
                        height: 14
                        radius: 7
                        color: "transparent"
                        border.width: 2
                        border.color: "#FFFFFF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor

                        function pick(x) {
                            const h = Math.max(0, Math.min(1, x / width));
                            const c = Qt.hsla(h, 0.8, 0.55, 1);
                            Theme.setUser("color.accent", c.toString().toUpperCase());
                        }

                        onPressed: event => pick(event.x)
                        onPositionChanged: event => {
                            if (pressed)
                                pick(event.x);
                        }
                    }
                }

                TextField {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 104
                    height: 30
                    placeholder: "#E5252B"
                    text: page.chosen
                    onAccepted: value => {
                        const hex = value.trim().replace(/^#?/, "#");
                        if (/^#([0-9a-fA-F]{6})$/.test(hex))
                            Theme.setUser("color.accent", hex.toUpperCase());
                    }
                }
            }
        }
    }

    // The same colours in your apps. Each switch writes that app's theme and,
    // the first time, adds the one line that loads it.
    SettingCard {
        title: "apps"
        footnote: "Follows the accent, light or dark, and matugen's colours when those are on. Turning one off stops updating it; your app keeps the last colours until you change its theme."

        Repeater {
            model: [
                { id: "terminal", title: "Terminal", detail: "kitty and ghostty change at once; foot and alacritty from the next window." },
                { id: "gtk", title: "GTK apps", detail: "Files, Text Editor and other GTK and libadwaita apps, from their next launch." },
                { id: "spotify", title: "Spotify", detail: "Through Spicetify. Switching on restarts Spotify once to apply the theme." },
                { id: "discord", title: "Vesktop / Discord", detail: "Through Vencord. Then pick Stratum under Vencord → Themes, once." }
            ]

            SettingRow {
                id: appRow

                required property var modelData

                title: appRow.modelData.title
                detail: appRow.modelData.detail

                Switch {
                    checked: Config.get(`apps.theme.${appRow.modelData.id}`, false)
                    onToggled: value => value ? AppTheme.connect(appRow.modelData.id) : AppTheme.disconnect(appRow.modelData.id)
                }
            }
        }
    }

    SettingCard {
        title: "windows"
        footnote: "Applied to Hyprland straight away, and kept after it reloads. \"As in config\" leaves your Hyprland config in charge."

        SettingRow {
            title: "Borders and glow"
            detail: "Window borders and their glow in the shell's colours, matching your apps."

            Segmented {
                model: ["shell colours", "as in config"]
                current: Decor.borders === "config" ? 1 : 0
                onPicked: index => Config.set("windows.borders", index === 1 ? "config" : "accent")
            }
        }

        SettingRow {
            title: "Blur"
            detail: "How strongly see-through windows blur what is behind them."

            Segmented {
                readonly property var values: ["config", "off", "light", "medium", "strong"]

                model: ["as in config", "off", "light", "medium", "strong"]
                // A preset is lit only when the slider sits exactly on it.
                current: Decor.blur === "config" ? 0
                    : Math.max(-1, ["off", "light", "medium", "strong"].findIndex(n => Decor.presets[n] === Decor.amount) + 1) || -1
                onPicked: index => {
                    if (index === 0) {
                        Config.set("windows.blur", "config");
                        // Back to the config's own values.
                        Quickshell.execDetached(["hyprctl", "reload"]);
                    } else {
                        Decor.setAmount(Decor.presets[values[index]]);
                    }
                }
            }
        }

        SettingRow {
            visible: Decor.blur !== "config"
            title: "Blur strength"
            detail: Decor.amount === 0 ? "Off" : `${Decor.amount}%`

            Row {
                spacing: Theme.space(3)

                LevelSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 240
                    count: 25
                    step: 0.05
                    value: Decor.amount / 100
                    onMoved: v => Decor.setAmount(v * 100)
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40
                    horizontalAlignment: Text.AlignRight
                    text: `${Decor.amount}%`
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    SettingCard {
        title: "clock"

        SettingRow {
            title: "24-hour time"
            detail: "Off shows 3:41 instead of 15:41 in the bar, the control centre and the dashboard."

            Switch {
                checked: !Time.twelveHour
                onToggled: value => Config.set("clock.twelveHour", !value)
            }
        }
    }
}
