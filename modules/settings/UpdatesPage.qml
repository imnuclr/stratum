pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The version you are on, what is waiting, and the button to get it.
 */
SettingsPage {
    id: page

    icon: "arrow-down"
    title: "Updates"
    detail: Updates.version.length > 0 ? `You're on ${Updates.version}, from ${Updates.date}${Updates.branch ? ` (${Updates.branch})` : ""}.` : "Reading the installed version…"

    Component.onCompleted: Updates.check()

    // Showing the custom hours: on when chosen, or when the saved value is not
    // one of the presets.
    property bool custom: ![1, 6, 24].includes(Updates.everyHours)

    // What is happening, large enough to answer the question at a glance.
    Rectangle {
        height: 120
        radius: Theme.rTile
        color: Theme.surfaceHi
        border.width: 1
        border.color: Theme.line

        Column {
            anchors.left: parent.left
            anchors.leftMargin: Theme.space(6)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(1)

            Text {
                text: Updates.state === "checking" ? "Checking…"
                    : Updates.state === "updating" ? "Updating — Stratum will restart"
                    : Updates.state === "failed" ? "Couldn't check"
                    : Updates.count > 0 ? (Updates.count === 1 ? "1 update ready" : `${Updates.count} updates ready`)
                    : "Up to date"
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: 24
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }

            Text {
                text: Updates.state === "failed" ? Updates.error
                    : Updates.dirty ? "You have changed files in the Stratum folder, so updating is paused. See: git status"
                    : Updates.checkedAt.length > 0 ? `Checked at ${Updates.checkedAt}.` : ""
                color: Updates.state === "failed" || Updates.dirty ? Theme.danger : Theme.fgDim
                font.family: Theme.fontUi
                font.pixelSize: 13
                renderType: Text.NativeRendering
            }
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: Theme.space(5)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space(2)

            LinkButton {
                text: "check now"
                onClicked: Updates.check()
            }

            LinkButton {
                visible: Updates.count > 0 && !Updates.dirty
                icon: "arrow-down"
                text: "update and restart"
                onClicked: Updates.update()
            }
        }
    }

    SettingCard {
        title: "what's new"
        visible: Updates.count > 0

        Repeater {
            model: Updates.waiting

            SettingRow {
                id: change

                required property var modelData

                title: change.modelData.title
                detail: `${change.modelData.hash} · ${change.modelData.when}`
            }
        }
    }

    SettingCard {
        title: "checking"

        SettingRow {
            title: "Check automatically"
            detail: "Tells you when something new is ready, once per new version."

            Switch {
                checked: Updates.automatic
                onToggled: value => Config.set("updates.check", value)
            }
        }

        SettingRow {
            visible: Updates.automatic
            title: "How often"
            detail: "Also checked a minute or so after Stratum starts, and whenever this page opens."

            Segmented {
                readonly property var hours: [1, 6, 24]

                model: ["every hour", "every 6 hours", "daily", "custom"]
                // Custom is lit for anything that is not one of the three.
                current: page.custom ? 3 : Math.max(0, hours.indexOf(Updates.everyHours))
                onPicked: index => {
                    if (index === 3) {
                        page.custom = true;
                        return;
                    }
                    page.custom = false;
                    Config.set("updates.everyHours", hours[index]);
                }
            }
        }

        SettingRow {
            visible: Updates.automatic && page.custom
            title: "Every"
            detail: "Any number of hours, from one to a week."

            Stepper {
                value: Updates.everyHours
                from: 1
                to: 168
                step: 1
                suffix: Updates.everyHours === 1 ? " hour" : " hours"
                onMoved: v => Config.set("updates.everyHours", v)
            }
        }
    }
}
