import QtQuick
import Quickshell
import qs.services
import qs.theme

/*
 * One notification inside an app's group.
 *
 * Collapsed it is a single line: who it is from, then as much of what they said
 * as fits. Folded into a group the app's name is already on the header above, so
 * the line spends its width on the part that differs between one ping and the
 * next.
 *
 * Clicking opens it rather than launching the app. A one-line summary is enough
 * to triage but not always enough to read, and a list where the only way to see
 * the rest of a message is to jump into the application is a list you cannot
 * actually read. Expanded it wraps the full body and shows whatever buttons the
 * sender offered — including going to the app, which is now something you choose
 * rather than something a stray click does to you.
 *
 * The sender's picture rather than the app's, where there is one — in a chat app
 * that is the person, which is the thing you are scanning for.
 */
Item {
    id: root

    required property var notification

    property bool expanded: false

    readonly property bool critical: Notifs.isCritical(root.notification)
    readonly property string face: Notifs.iconFor(root.notification, false)

    readonly property var actions: (root.notification?.actions ?? [])
        .filter(a => a.identifier !== "default")
    readonly property bool canOpen: (root.notification?.actions ?? []).length > 0
        || !!(root.notification?.desktopEntry)

    implicitHeight: column.implicitHeight + Theme.space(2)

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.standard
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.smooth
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: -Theme.space(1)
        anchors.rightMargin: -Theme.space(1)
        radius: Theme.rInner
        color: root.expanded
            ? Qt.alpha(Theme.fg, 0.07)
            : (hover.hovered ? Qt.alpha(Theme.fg, 0.06) : "transparent")

        Behavior on color {
            ColorAnimation {
                duration: Theme.micro
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.smooth
            }
        }
    }

    DotAvatar {
        id: avatar

        anchors.left: parent.left
        // Rides with the first line once the body wraps below it.
        anchors.top: parent.top
        anchors.topMargin: Theme.space(1)

        size: 20
        dotSize: 1.5
        source: root.face
        name: root.notification?.summary ?? ""
        // Only ring an actual face. A column of empty dotted rings beside
        // notifications that carry no picture is just texture.
        ringColor: root.critical
            ? Theme.accent
            : (root.face.length > 0 ? Qt.alpha(Theme.fg, 0.25) : "transparent")
    }

    Column {
        id: column

        anchors.left: avatar.right
        anchors.leftMargin: Theme.space(2)
        anchors.right: parent.right
        anchors.rightMargin: Theme.space(3)
        anchors.top: parent.top
        anchors.topMargin: Theme.space(1)

        spacing: Theme.space(1)

        Text {
            id: text

            width: parent.width

            // Elided to one line until opened, then allowed to wrap.
            elide: root.expanded ? Text.ElideNone : Text.ElideRight
            wrapMode: root.expanded ? Text.Wrap : Text.NoWrap
            textFormat: Text.StyledText
            font.family: Theme.fontUi
            font.pixelSize: 13
            color: Theme.fgBright
            renderType: Text.NativeRendering
            lineHeight: root.expanded ? 1.25 : 1

            /*
             * Sender and message told apart by weight rather than a separator:
             * the eye picks bold out of a column of these far faster than it
             * finds a middot. Escaped, because a notification body is arbitrary
             * text and StyledText would otherwise read a stray angle bracket as
             * markup and eat the rest of the line.
             */
            function esc(s) {
                return String(s ?? "")
                    .replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;")
                    .replace(/\s+/g, " ")
                    .trim();
            }

            text: {
                const summary = text.esc(root.notification?.summary);
                const detail = text.esc(root.notification?.body);
                const head = `<font color="${root.critical ? Theme.accent : Theme.fg}">${summary}</font>`;
                if (detail.length === 0)
                    return head;
                // Opened, the body gets its own line so it can wrap as a
                // paragraph rather than trailing off the summary.
                return root.expanded ? `${head}<br/>${detail}` : `${head} ${detail}`;
            }
        }

        /*
         * Whatever the sender offered, plus a way into the app — shown only once
         * the notification is open, so a glance costs nothing.
         *
         * Real pill buttons, not bare labels. A caps micro-label is a signpost,
         * not a target: it was a few pixels tall with no edges, so hitting it
         * meant aiming. These are the shell's standard 32px pill, which is a
         * thing you press rather than a word you have to find.
         */
        Item {
            width: parent.width
            height: root.expanded ? actions.implicitHeight + Theme.space(1) : 0
            visible: root.expanded
            clip: true

            // Flow, not Row: three buttons plus a long action label ran off the
            // side of the panel and the last one was cut in half. They wrap now.
            Flow {
                id: actions

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: Theme.space(2)

                Repeater {
                    model: root.actions

                    ActionPill {
                        required property var modelData

                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }

                // Last, and quieter: going to the app is the shell's offer, not
                // something the sender asked for, and it should not read as the
                // obvious thing to press. No icon either — it was the only
                // button carrying one, which made it look bolted on.
                ActionPill {
                    visible: root.canOpen
                    secondary: true
                    text: "open"
                    onClicked: Notifs.activate(root.notification)
                }
            }
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.expanded = !root.expanded
    }

    // Dismiss just this one, without opening the app it came from.
    Glyph {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.space(1)

        name: "close"
        size: 11
        visible: hover.hovered || root.expanded
        color: closeHover.hovered ? Theme.fg : Theme.fgDim

        HoverHandler {
            id: closeHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: Notifs.dismiss(root.notification)
        }
    }
}
