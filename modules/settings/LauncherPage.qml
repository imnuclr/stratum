import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * The launcher: what it searches, and how it is opened.
 */
SettingsPage {
    id: page

    readonly property var bind: Binds.own.find(b => b.action === "launcher") ?? null
    readonly property var engines: ["duckduckgo", "google", "brave", "startpage"]

    icon: "search"
    title: "Launcher"
    detail: page.bind ? `Open it with ${Binds.combo(page.bind.mods, page.bind.key)}, then just type.` : "Give it a key under Keybinds, then just type."

    SettingCard {
        title: "search"

        SettingRow {
            title: "Files"
            detail: "Looks through your home folder as you type. Fastest with plocate installed."

            Switch {
                checked: Config.get("launcher.files", true)
                onToggled: value => Config.set("launcher.files", value)
            }
        }

        SettingRow {
            title: "Recent files"
            detail: "Shows what you opened lately before you type anything."

            Switch {
                checked: Config.get("launcher.recent", true)
                onToggled: value => Config.set("launcher.recent", value)
            }
        }

        SettingRow {
            title: "Calculator"
            detail: "Type a sum like 12 * 4.5 and the answer is the first result. Enter copies it."

            Switch {
                checked: Config.get("launcher.calc", true)
                onToggled: value => Config.set("launcher.calc", value)
            }
        }

        SettingRow {
            title: "Search the web"
            detail: "Offers a web search as the last result."

            Switch {
                checked: Config.get("launcher.web", true)
                onToggled: value => Config.set("launcher.web", value)
            }
        }

        SettingRow {
            visible: Config.get("launcher.web", true)
            title: "Search engine"

            Segmented {
                model: page.engines
                current: Math.max(0, page.engines.indexOf(Config.get("launcher.engine", "duckduckgo")))
                onPicked: index => Config.set("launcher.engine", page.engines[index])
            }
        }
    }

    SettingCard {
        title: "learning"

        SettingRow {
            title: "Rank by use"
            detail: `Apps you open more float to the top. ${Object.keys(Launcher.counts).length} apps remembered so far.`

            LinkButton {
                text: "forget"
                danger: true
                onClicked: Launcher.forget()
            }
        }
    }

    SettingCard {
        title: "keyboard"

        SettingRow {
            title: "Shortcut"
            detail: page.bind ? Binds.combo(page.bind.mods, page.bind.key) : "none"

            LinkButton {
                text: "change"
                onClicked: Shell.settingsPage = "keybinds"
            }
        }
    }
}
