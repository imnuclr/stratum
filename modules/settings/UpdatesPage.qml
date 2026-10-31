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
    property bool custom: ![60, 360, 1440].includes(Updates.everyMinutes)

    // The unit the custom number is shown in: the largest that divides it.
    readonly property var units: [["minutes", 1], ["hours", 60], ["days", 1440]]
    readonly property int unit: Updates.everyMinutes % 1440 === 0 ? 2 : (Updates.everyMinutes % 60 === 0 ? 1 : 0)

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
                readonly property var minutes: [60, 360, 1440]

                model: ["every hour", "every 6 hours", "daily", "custom"]
                // Custom is lit for anything that is not one of the three.
                current: page.custom ? 3 : Math.max(0, minutes.indexOf(Updates.everyMinutes))
                onPicked: index => {
                    if (index === 3) {
                        page.custom = true;
                        return;
                    }
                    page.custom = false;
                    Config.set("updates.everyMinutes", minutes[index]);
                }
            }
        }

        SettingRow {
            visible: Updates.automatic && page.custom
            title: "Every"
            detail: "From a minute to a month. Checking is one small request, so often is cheap."

            Row {
                spacing: Theme.space(3)

                Stepper {
                    anchors.verticalCenter: parent.verticalCenter

                    readonly property int size: page.units[page.unit][1]

                    value: Math.max(1, Math.round(Updates.everyMinutes / size))
                    from: 1
                    to: page.unit === 0 ? 59 : (page.unit === 1 ? 23 : 31)
                    step: 1
                    onMoved: v => Config.set("updates.everyMinutes", Math.round(v) * size)
                }

                Segmented {
                    anchors.verticalCenter: parent.verticalCenter

                    model: page.units.map(u => u[0])
                    current: page.unit
                    // Keeping the number and changing the unit: 6 hours becomes
                    // 6 minutes, which is what picking "minutes" means.
                    onPicked: index => {
                        const now = Math.max(1, Math.round(Updates.everyMinutes / page.units[page.unit][1]));
                        const cap = index === 0 ? 59 : (index === 1 ? 23 : 31);
                        Config.set("updates.everyMinutes", Math.min(now, cap) * page.units[index][1]);
                    }
                }
            }
        }
    }
}
