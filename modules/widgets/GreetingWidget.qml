import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * A greeting by the hour, the name, and two small facts underneath.
 */
Item {
    id: root

    readonly property string greeting: {
        const h = Time.hours;
        if (h < 5)
            return "Good night";
        if (h < 12)
            return "Good morning";
        if (h < 18)
            return "Good afternoon";
        return "Good evening";
    }
    readonly property real type: Math.max(18, Math.min(root.height * 0.36, root.width / 11))

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(root.type * 0.12)

        Text {
            text: `${root.greeting},`
            color: Theme.fg
            font.family: Theme.fontRounded
            font.pixelSize: root.type
            font.weight: Font.Light
            renderType: Text.NativeRendering
        }

        Text {
            text: `${Account.firstName.length > 0 ? Account.firstName : Account.user}.`
            color: Theme.fgDim
            font.family: Theme.fontRounded
            font.pixelSize: root.type
            font.weight: Font.Light
            renderType: Text.NativeRendering
        }

        Row {
            spacing: Theme.space(4)
            topPadding: Theme.space(1)

            Row {
                spacing: Theme.space(2)

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Notifs.any ? "bell" : "bell-off"
                    size: 14
                    color: Theme.fgBright
                }

                SectionLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Notifs.count} ${Notifs.count === 1 ? "notification" : "notifications"}`
                    color: Theme.fgBright
                }
            }

            SectionLabel {
                visible: Weather.ready
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(Weather.temperature)}° ${Weather.condition}`
                color: Theme.fgBright
            }
        }
    }
}
