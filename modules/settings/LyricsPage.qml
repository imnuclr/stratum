import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme

/*
 * Where the words come from, and whether they land with the voice.
 *
 * The key is the whole of the setup, and it is worth being plain about why:
 * word-by-word timing exists in exactly one public place, it is free, and it
 * costs a minute to fetch. Everything else on this page is a preference.
 */
SettingsPage {
    id: page

    icon: "play"
    title: "Lyrics"
    detail: "Word-by-word lyrics on the desktop and over the whole screen."

    SettingCard {
        SettingRow {
            width: parent.width
            title: "Lyrics"
            detail: "Looks up the words for whatever is playing, while something is showing them."

            Switch {
                checked: Config.get("lyrics.enabled", true)
                onToggled: value => Config.set("lyrics.enabled", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Full screen"
            detail: "The whole song, to read along with. Also on Super+Y, and in Keybinds."

            ActionButton {
                text: "open"
                width: 108
                onClicked: {
                    Shell.closeSettings();
                    Shell.open("lyrics");
                }
            }
        }

        SettingRow {
            width: parent.width
            title: "On the desktop"
            detail: "Add a lyrics widget: right-click the wallpaper to arrange, then pick it from the row of widgets."

            ActionButton {
                text: "arrange"
                width: 108
                onClicked: {
                    Shell.closeSettings();
                    Widgets.editing = true;
                }
            }
        }
    }

    /*
     * The key. Stored in a file of its own rather than in shell.json, which is
     * the file people paste into issues and push to dotfile repos — a secret
     * does not belong in it.
     */
    SettingCard {
        title: "spicy lyrics"
        footnote: Lyrics.haveKey
            ? `Stored in ${Lyrics.keyPath.replace(Quickshell.env("HOME"), "~")}, which nothing else reads.`
            : "Free, and takes about a minute: make an application at developers.spicylyrics.org, then paste the secret key here. Without one the shell falls back to LRCLIB, which only knows where each line starts — so the lines light whole instead of being swept word by word."

        SettingRow {
            width: parent.width
            title: "Key"
            detail: Lyrics.haveKey ? "A key is set. Paste another to replace it." : "Starts sl_sk_…"

            Row {
                spacing: Theme.space(3)

                TextField {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    text: ""
                    placeholder: Lyrics.haveKey ? "••••••••••••••••" : "sl_sk_…"
                    onFinished: value => {
                        if (value.trim().length > 0) {
                            Lyrics.saveKey(value);
                            Lyrics.refresh(true);
                        }
                    }
                }

                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "forget"
                    width: 90
                    enabled: Lyrics.haveKey
                    onClicked: Lyrics.saveKey("")
                }
            }
        }

        SettingRow {
            width: parent.width
            title: "Get a key"
            detail: "Opens the developer dashboard. Create an application; the secret key is shown once."

            ActionButton {
                text: "open"
                width: 108
                onClicked: Quickshell.execDetached(["xdg-open", "https://developers.spicylyrics.org/docs"])
            }
        }
    }

    SettingCard {
        title: "timing"
        footnote: "Position comes over a bus and is always a little behind what has actually been played. Nudge until the sweep lands on the voice."

        SettingRow {
            width: parent.width
            title: "Offset"
            detail: Config.get("lyrics.offsetMs", 0) === 0
                ? "No shift."
                : (Config.get("lyrics.offsetMs", 0) > 0 ? "The words run ahead of the sound." : "The words lag behind the sound.")

            Stepper {
                value: Config.get("lyrics.offsetMs", 0)
                from: -2000
                to: 2000
                step: 50
                suffix: "ms"
                onMoved: v => Config.set("lyrics.offsetMs", v)
            }
        }

        SettingRow {
            width: parent.width
            title: "Depth of field"
            detail: "In the full-screen view, lines away from the one being sung go soft. Off draws them all sharp, which costs a little less."

            Switch {
                checked: Config.get("lyrics.depth", true)
                onToggled: value => Config.set("lyrics.depth", value)
            }
        }

        SettingRow {
            width: parent.width
            title: "Try it"
            detail: "Four placeholder lines, timed from here, so both kinds can be seen without waiting for a track that has them. Not every track has word timings, whatever the key."

            Row {
                spacing: Theme.space(2)

                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "word by word"
                    width: 128
                    onClicked: {
                        Shell.closeSettings();
                        Shell.open("lyrics");
                        Lyrics.sample("word");
                    }
                }

                ActionButton {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "by line"
                    width: 94
                    onClicked: {
                        Shell.closeSettings();
                        Shell.open("lyrics");
                        Lyrics.sample("line");
                    }
                }
            }
        }
    }

    SettingCard {
        title: "what is playing"
        footnote: "What the shell knows right now. `stratum ipc call lyrics status` says the same thing in a terminal."

        SettingRow {
            width: parent.width
            implicitHeight: Math.max(72, report.implicitHeight + Theme.space(5))
            title: ""
            detail: ""

            Text {
                id: report

                anchors.verticalCenter: parent.verticalCenter
                width: 420
                wrapMode: Text.WordWrap
                text: Lyrics.report()
                color: Theme.fgDim
                font.family: Theme.fontDot
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }
        }
    }
}
