import QtQuick
import qs.components
import qs.config
import qs.theme

/*
 * How quickly things move. One setting scales every animation in the shell, so
 * panels, popouts and dots all stay in step with each other.
 */
SettingsPage {
    id: page

    readonly property var speeds: [0, 0.6, 1, 1.6]
    readonly property var names: ["off", "brisk", "normal", "relaxed"]
    readonly property real speed: Config.get("motion.speed", 1)

    icon: "motion"
    title: "Motion"
    detail: "Animation speed for panels, popouts and everything else that moves."

    // A dot running back and forth at the chosen speed, so the choice can be
    // felt before going anywhere else.
    Rectangle {
        height: 120
        radius: Theme.rTile
        color: Theme.surfaceHi
        border.width: 1
        border.color: Theme.line

        DotField {
            anchors.centerIn: parent
            rows: 1
            columnSpacing: Theme.dotPitch - Theme.dot
            values: Array.from({ length: Math.floor((parent.width - 80) / Theme.dotPitch) }, () => 0)
        }

        Rectangle {
            id: runner

            readonly property real span: parent.width - 80

            x: 40
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.dot * 4
            height: Theme.dot * 4
            radius: width / 2
            color: Theme.accent

            SequentialAnimation on x {
                running: Theme.sheetMs > 0
                loops: Animation.Infinite

                NumberAnimation {
                    from: 40
                    to: 40 + runner.span - runner.width
                    duration: Math.max(1, Theme.sheetMs * 4)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }

                PauseAnimation {
                    duration: 500
                }

                NumberAnimation {
                    from: 40 + runner.span - runner.width
                    to: 40
                    duration: Math.max(1, Theme.sheetMs * 4)
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.soft
                }

                PauseAnimation {
                    duration: 500
                }
            }
        }
    }

    SettingCard {
        title: "speed"
        footnote: "Off still changes things instantly — nothing is hidden, it just doesn't travel."

        SettingRow {
            title: "Animation speed"
            detail: page.speed === 0 ? "No animation." : `${Math.round(page.speed * 100)}% of the designed length.`

            Segmented {
                model: page.names
                current: {
                    let best = 0;
                    for (let i = 0; i < page.speeds.length; i++)
                        if (Math.abs(page.speeds[i] - page.speed) < Math.abs(page.speeds[best] - page.speed))
                            best = i;
                    return best;
                }
                onPicked: index => Config.set("motion.speed", page.speeds[index])
            }
        }

        SettingRow {
            title: "Fine tune"
            detail: "Anywhere from instant to twice as slow."

            Stepper {
                value: Math.round(page.speed * 100)
                from: 0
                to: 200
                step: 10
                suffix: "%"
                onMoved: v => Config.set("motion.speed", v / 100)
            }
        }
    }

    SettingCard {
        title: "wallpaper"

        SettingRow {
            title: "Cross-fade"
            detail: "How long one wallpaper takes to fade into the next."

            Stepper {
                value: Config.get("wallpaper.fadeMs", 150)
                from: 0
                to: 1500
                step: 50
                suffix: " ms"
                onMoved: v => Config.set("wallpaper.fadeMs", v)
            }
        }
    }
}
