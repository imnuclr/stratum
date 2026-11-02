import QtQuick
import qs.components
import qs.modules.widgets
import qs.services
import qs.theme

/*
 * Charge, how long it will last or take, and the power profile.
 *
 * The profile lives here rather than as a second icon in the bar because it is
 * the same question from the other side: how much to spend of what is left.
 * What the machine is drawing sits opposite the charge, read while this is open.
 */
Item {
    id: root

    implicitWidth: 286
    implicitHeight: body.implicitHeight

    Watch {
        service: Watts
        live: Popouts.open
    }

    Column {
        id: body

        width: parent.width
        spacing: Theme.space(2)

        Item {
            width: body.width
            height: Math.max(charge.implicitHeight, draw.implicitHeight)

        Row {
            id: charge

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(2)

            DotText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(Power.percentage * 100)}`
                size: 34
                plain: true
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Text {
                    text: Power.full ? "Fully charged" : (Power.charging ? "Charging" : "On battery")
                    color: Theme.fg
                    font.family: Theme.fontUi
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    renderType: Text.NativeRendering
                }

                Text {
                    color: Theme.fgBright
                    font.family: Theme.fontUi
                    font.pixelSize: 14
                    renderType: Text.NativeRendering
                    text: {
                        if (Power.full)
                            return "Plugged in";
                        const t = Power.charging ? Power.timeToFull : Power.timeToEmpty;
                        if (t <= 0)
                            return "Estimating…";
                        return Power.charging ? `${Power.formatTime(t)} until full` : `${Power.formatTime(t)} remaining`;
                    }
                }
            }
        }

        /*
         * What the machine is drawing, opposite the charge and the same size:
         * from the battery while on it, going into it while charging. Nothing
         * is shown when neither can be read.
         */
        Row {
            id: draw

            readonly property real watts: Watts.available ? Watts.total : Watts.charging

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            visible: draw.watts > 0

            DotText {
                anchors.verticalCenter: parent.verticalCenter
                // Whole watts, like the percentage opposite: Doto's decimal
                // point is a cross of dots and read as "6+0".
                text: `${Math.max(1, Math.round(draw.watts))}`
                size: 34
                plain: true
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "W"
                color: Theme.fgDim
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.weight: Font.Medium
                renderType: Text.NativeRendering
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
    }
}
