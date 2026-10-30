pragma ComponentBehavior: Bound

import QtQuick
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
Item {
    id: page

    // The preset's own accent, which the first swatch stands for.
    readonly property string presetAccent: Theme.preset?.color?.accent ?? "#E5252B"
    readonly property string chosen: Theme.user?.color?.accent ?? ""

    readonly property var swatches: [
        "",
        "#FF6A1A", "#FFB800", "#3DDC84", "#22D3EE", "#3B82F6", "#8B5CF6", "#EC4899", "#F4F4F5"
    ]

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 0

        SectionLabel {
            text: "appearance"
            bottomPadding: Theme.space(3)
        }

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
            implicitHeight: 112
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
    }
}
