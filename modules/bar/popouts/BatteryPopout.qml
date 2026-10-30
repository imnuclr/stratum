import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Charge, how long it will last or take, and the power profile.
 *
 * The profile lives here rather than as a second icon in the bar because it is
 * the same question from the other side: how much to spend of what is left.
 */
Item {
    id: root

    implicitWidth: 286
    implicitHeight: body.implicitHeight

    readonly property var blurbs: ({
        "power-saver": "Quietest and longest-lasting. The processor is held back.",
        "balanced": "The everyday default.",
        "performance": "Fastest, and warmest. Uses the most power."
    })

    Column {
        id: body

        width: parent.width
        spacing: Theme.space(2)

        Row {
            spacing: Theme.space(2)

            DotText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(Power.percentage * 100)}`
                size: 34
                plain: true
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                SectionLabel {
                    text: Power.full ? "fully charged" : (Power.charging ? "charging" : "on battery")
                    dim: false
                }

                SectionLabel {
                    dim: true
                    text: {
                        if (Power.full)
                            return "plugged in";
                        const t = Power.charging ? Power.timeToFull : Power.timeToEmpty;
                        if (t <= 0)
                            return "estimating…";
                        return Power.charging ? `${Power.formatTime(t)} until full` : `${Power.formatTime(t)} remaining`;
                    }
                }
            }
        }

        Rectangle {
            width: body.width
            height: 1
            color: Theme.line
        }

        SectionLabel {
            text: "Power profile"
        }

        Rectangle {
            width: body.width
            height: profiles.height
            radius: height / 2
            color: Theme.surfaceHi

            SegmentedProfiles {
                id: profiles

                width: parent.width
            }
        }

        SectionLabel {
            width: body.width
            wrapMode: Text.WordWrap
            dim: true
            font.capitalization: Font.MixedCase
            font.letterSpacing: 0
            font.pixelSize: 12
            text: root.blurbs[Power.profile] ?? ""
        }
    }
}
