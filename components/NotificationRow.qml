import QtQuick
import Quickshell
import qs.services
import qs.theme

/*
 * One notification. The app and the age sit on the header line, the summary and
 * body beneath — the sender matters more than the title for deciding whether to
 * read it, so it leads.
 *
 * The whole row is the way into the application: clicking it invokes whatever
 * the sender offered, or brings that application forward. Dismissing is a
 * separate target in the corner, always drawn, because a close affordance that
 * only appears on hover cannot be found by someone looking for it — and on a
 * page whose entire purpose is reading and clearing, that is the one control
 * that has to be obvious.
 */
Rectangle {
    id: root

    required property var notification

    /*
     * Urgency, which the row had been ignoring entirely — a battery warning and
     * a now-playing ping were drawn exactly alike. Critical is the one case the
     * design allows colour for: the sender is saying this should not be missed,
     * and nothing else on the row earns the accent.
     */
    readonly property bool critical: Notifs.isCritical(root.notification)
    readonly property bool low: Notifs.isLow(root.notification)

    readonly property var extraActions: (root.notification?.actions ?? [])
        .filter(a => a.identifier !== "default")

    /*
     * What stands for the notification. A picture the sender attached comes
     * first — a chat app sends the person's profile picture that way, and who
     * a message is from matters more than which app carried it. Otherwise the
     * application's icon, wherever it can be found: what the notification
     * names, a file it points at, the icon of its desktop entry, or an icon
     * named after the app. Empty when there is none.
     */
    readonly property string iconSource: {
        const n = root.notification;
        if (!n)
            return "";
        const picture = n.image ?? "";
        if (picture.length > 0)
            return picture.startsWith("/") ? `file://${picture}` : picture;
        const named = n.appIcon ?? "";
        if (named.startsWith("/"))
            return `file://${named}`;
        if (named.startsWith("file://") || named.startsWith("image://"))
            return named;
        const tries = [named];
        const entry = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null;
        if (entry?.icon)
            tries.push(entry.icon);
        if (n.desktopEntry)
            tries.push(n.desktopEntry);
        if (n.appName)
            tries.push(n.appName.toLowerCase(), n.appName.toLowerCase().replace(/\s+/g, "-"));
        for (const t of tries) {
            if (!t)
                continue;
            const p = Quickshell.iconPath(t, true);
            if (p && p.length > 0)
                return p;
        }
        return "";
    }

    implicitHeight: Math.max(content.implicitHeight, badge.height) + Theme.space(3) * 2

    radius: Theme.rTile
    opacity: 1 - Math.min(0.9, Math.abs(root.slide) / Math.max(1, root.width))
    color: hover.hovered ? Theme.surfaceTop : Theme.surfaceHi
    border.width: 1
    border.color: root.critical ? Theme.accent : (hover.hovered ? Theme.fg : Theme.outline)

    Behavior on color {
        ColorAnimation {
            duration: Theme.micro
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.smooth
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.micro
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.smooth
        }
    }

    /*
     * The sender's picture, or failing that the app's icon — as a photo in a
     * ring of dots, not dithered into them. A face rendered as dots is muddy and
     * genuinely hard to recognise at this size, which is the whole reason the
     * lock screen stopped doing it to the user's avatar. The dots belong around
     * the picture.
     */
    DotAvatar {
        id: badge

        /*
         * Level with the first line, not the middle. Centring put the icon
         * halfway down a three-line notification while the text it belongs to
         * started at the top, so the two read as unrelated.
         */
        anchors.left: parent.left
        anchors.leftMargin: Theme.space(3)
        anchors.top: parent.top
        anchors.topMargin: Theme.space(3)

        size: 40
        source: root.iconSource
        name: root.notification?.appName ?? ""
        ringColor: root.critical ? Theme.accent : Theme.fgFaint
    }

    Column {
        id: content

        anchors.left: badge.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.space(3)
        // Top-aligned to match the icon. Centring this while the icon sat at the
        // top left the two drifting apart as the body grew.
        anchors.topMargin: Theme.space(3)
        spacing: Theme.space(1)

        Item {
            width: parent.width
            height: app.implicitHeight

            SectionLabel {
                id: app

                anchors.left: parent.left
                anchors.right: dismiss.left
                anchors.rightMargin: Theme.space(2)
                elide: Text.ElideRight
                // Says which app, and — when it matters — how much it matters.
                // Low urgency sits back rather than shouting.
                color: root.critical ? Theme.accent : (root.low ? Theme.fgDim : Theme.fgBright)
                text: `${root.notification?.appName ?? "system"} · ${Notifs.age(root.notification)}`

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.standard
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.smooth
                    }
                }
            }

            // Always drawn, dim until pointed at. The target is larger than the
            // glyph so it can be hit without aiming.
            Item {
                id: dismiss

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.space(4)
                height: Theme.space(4)

                Glyph {
                    anchors.centerIn: parent
                    name: "close"
                    size: 14
                    color: closeHover.hovered ? Theme.fg : Theme.fgDim

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.micro
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.smooth
                        }
                    }
                }

                HoverHandler {
                    id: closeHover

                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: Notifs.dismiss(root.notification)
                }
            }
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.notification?.summary ?? ""
            visible: text.length > 0
            color: Theme.fg
            font.family: Theme.fontUi
            font.pixelSize: 16
            font.weight: Font.Medium
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            // Senders are allowed limited markup, and the server advertises
            // support for it, so it has to be rendered rather than shown raw.
            textFormat: Text.StyledText
            text: root.notification?.body ?? ""
            visible: text.length > 0
            color: Theme.fgBright
            font.family: Theme.fontUi
            font.pixelSize: 14
            renderType: Text.NativeRendering
        }

        // Anything the sender offered beyond the default, as its own target.
        Row {
            spacing: Theme.space(2)
            visible: root.extraActions.length > 0

            Repeater {
                model: root.extraActions

                SectionLabel {
                    required property var modelData

                    text: modelData.text
                    color: actionHover.hovered ? Theme.fg : Theme.fgBright

                    HoverHandler {
                        id: actionHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: modelData.invoke()
                    }
                }
            }
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    // Below the dismiss target and the action labels in the stack, so those win.
    TapHandler {
        onTapped: Notifs.activate(root.notification)
    }

    // A middle click dismisses, as it closes a tab.
    TapHandler {
        acceptedButtons: Qt.MiddleButton
        onTapped: Notifs.dismiss(root.notification)
    }

    /*
     * Flicked sideways, it follows the pointer and fades; let go past a third
     * of its width, or with a quick flick, and it is dismissed. Short of that
     * it settles back.
     */
    property real slide: 0

    transform: Translate {
        x: root.slide
    }

    Behavior on slide {
        enabled: !swipe.active

        NumberAnimation {
            duration: Theme.sheetMs
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.smooth
        }
    }

    DragHandler {
        id: swipe

        target: null
        yAxis.enabled: false
        cursorShape: active ? Qt.ClosedHandCursor : undefined

        onTranslationChanged: {
            if (active)
                root.slide = translation.x;
        }

        onActiveChanged: {
            if (active)
                return;
            const fast = Math.abs(centroid.velocity.x) > 900;
            if (Math.abs(root.slide) > root.width / 3 || fast) {
                root.slide = (root.slide >= 0 ? 1 : -1) * (root.width + 40);
                gone.restart();
            } else {
                root.slide = 0;
            }
        }
    }

    Timer {
        id: gone

        interval: Theme.sheetMs
        onTriggered: Notifs.dismiss(root.notification)
    }
}
