import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.theme
import qs.utils

/*
 * The control centre: the things you change, stacked, with notifications under
 * them. The dashboard is the counterpart — that one is what you read.
 *
 * Anchored to the bar's edge rather than centred, because every control in here
 * has a corresponding indicator on the bar and the two should line up.
 */
Sheet {
    id: root

    name: "control"
    hoverDismiss: true
    originX: 0
    sheetWidth: Config.get("control.width", 460)
    sheetHeight: Math.min(monitor.height - Theme.space(4) * 4, body.implicitHeight + Theme.space(4) * 2)

    onOpenChanged: {
        if (open) {
            Media.watch();
            Notifs.watch();
        } else {
            Media.unwatch();
            Notifs.unwatch();
        }
    }

    Column {
        id: body

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.space(4)
        spacing: Theme.space(3)

        SliderPill {
            width: parent.width
            icon: "brightness"
            value: Brightness.value
            label: `${Math.round(Brightness.value * 100)}`
            enabled: Brightness.ready
            onMoved: v => Brightness.set(v)
        }

        SliderPill {
            width: parent.width
            icon: Icons.volume(Audio.volume, Audio.muted)
            value: Audio.muted ? 0 : Audio.volume
            label: `${Math.round(Audio.volume * 100)}`
            onMoved: v => Audio.setVolume(v)
        }

        Rectangle {
            width: parent.width
            height: profiles.height
            radius: height / 2
            color: Theme.surfaceHi
            visible: Power.profiles.length > 1

            SegmentedProfiles {
                id: profiles

                width: parent.width
            }
        }

        // Media gets a tile rather than a row: it is the one block here that is
        // mostly a reading, so it reads as a card set into the stack.
        Rectangle {
            width: parent.width
            height: 96
            radius: Theme.rTile
            color: Theme.surfaceHi
            visible: Media.available

            Row {
                anchors.fill: parent
                anchors.margins: Theme.space(2)
                spacing: Theme.space(3)

                DotImage {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 72
                    height: 72
                    cell: 3
                    dotScale: 0.5
                    halftone: true
                    circular: true
                    source: Media.artUrl
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 72 - 150
                    spacing: 2

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Media.title
                        color: Theme.fg
                        font.family: Theme.fontUi
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        renderType: Text.NativeRendering
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Media.artist
                        color: Theme.fgDim
                        font.family: Theme.fontUi
                        font.pixelSize: 13
                        renderType: Text.NativeRendering
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space(2)

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "skip-back"
                        size: 16
                        filled: true
                        color: Media.canPrevious ? Theme.fgBright : Theme.fgFaint

                        TapHandler {
                            onTapped: Media.previous()
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46
                        height: 46
                        radius: width / 2
                        color: Theme.accent

                        Glyph {
                            anchors.centerIn: parent
                            name: Media.playing ? "pause" : "play"
                            size: 17
                            filled: true
                            color: Theme.bg
                        }

                        TapHandler {
                            onTapped: Media.playPause()
                        }
                    }

                    Glyph {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "skip-forward"
                        size: 16
                        filled: true
                        color: Media.canNext ? Theme.fgBright : Theme.fgFaint

                        TapHandler {
                            onTapped: Media.next()
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: Theme.space(2)
        }

        Item {
            width: parent.width
            height: header.implicitHeight

            SectionLabel {
                id: header

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.any ? `notifications · ${Notifs.count}` : "notifications"
            }

            SectionLabel {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "clear all"
                color: clearHover.hovered ? Theme.fg : Theme.fgBright
                visible: Notifs.any

                HoverHandler {
                    id: clearHover
                }

                TapHandler {
                    onTapped: Notifs.clearAll()
                }
            }
        }

        Repeater {
            model: Notifs.list

            NotificationRow {
                required property var modelData

                width: body.width
                notification: modelData
            }
        }

        SectionLabel {
            dim: true
            text: "nothing to show"
            visible: !Notifs.any
        }
    }
}
