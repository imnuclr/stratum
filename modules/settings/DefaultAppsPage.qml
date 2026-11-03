import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * Which application opens which kind of file. Every row is one format, with
 * the applications that can open it to choose from.
 */
SettingsPage {
    id: page

    icon: "file"
    title: "Default apps"
    detail: "Which application opens each kind of file, for every app on the system."

    Repeater {
        model: DefaultApps.groups

        SettingCard {
            id: card

            required property var modelData

            title: card.modelData.title

            Repeater {
                model: card.modelData.formats

                FormatRow {}
            }
        }
    }

    SettingCard {
        title: "another format"
        footnote: "Type an extension to find out what opens it, then choose."

        SettingRow {
            title: "Extension"
            detail: DefaultApps.customError

            Row {
                spacing: Theme.space(2)

                TextField {
                    id: field

                    width: 140
                    placeholder: "psd"
                    onAccepted: DefaultApps.lookup(field.text)
                }

                ActionButton {
                    text: "find"
                    width: 80
                    onClicked: DefaultApps.lookup(field.text)
                }
            }
        }

        FormatRow {
            modelData: DefaultApps.custom ?? ({ title: "", detail: "", mimes: [""] })
            visible: DefaultApps.custom !== null
        }
    }

    // One format, and the application that opens it.
    component FormatRow: SettingRow {
        id: row

        required property var modelData
        readonly property string mime: row.modelData.mimes[0]
        readonly property var names: DefaultApps.choices(row.mime)

        title: row.modelData.title
        detail: row.names.length > 0 ? row.modelData.detail : `${row.modelData.detail} · nothing installed opens this`

        Dropdown {
            menuWidth: 240
            visible: row.names.length > 0
            model: row.names
            current: DefaultApps.currentIndex(row.mime)
            onPicked: index => DefaultApps.choose(row.modelData, index)
        }
    }
}
