pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*
 * Who is signed in: the name to greet them by and the picture to show.
 *
 * The greeting uses your username unless you give another name in Settings →
 * Advanced (lock.name); the picture is lock.avatar, else ~/.face.
 */
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") ?? ""
    readonly property string home: Quickshell.env("HOME") ?? ""

    property string fullName: ""
    readonly property string firstName: {
        const configured = Config.get("lock.name", "");
        if (configured.length > 0)
            return configured;
        // Your username unless you set another in Settings → Advanced.
        return root.user;
    }

    // The first of these that exists is used: configured, then ~/.face (what
    // most desktops write), then AccountsService.
    readonly property var avatarCandidates: [
        Config.get("lock.avatar", ""),
        `${root.home}/.face`,
        `/var/lib/AccountsService/icons/${root.user}`
    ].filter(p => p.length > 0)

    property string avatar: ""

    onAvatarCandidatesChanged: {
        finder.running = false;
        finder.running = true;
    }

    Component.onCompleted: {
        names.running = true;
        finder.running = true;
    }

    Process {
        id: names

        command: ["getent", "passwd", root.user]

        stdout: StdioCollector {
            onStreamFinished: {
                // name:x:uid:gid:GECOS:home:shell, and GECOS is "Full Name,room,..."
                const gecos = text.trim().split(":")[4] ?? "";
                root.fullName = gecos.split(",")[0];
            }
        }
    }

    Process {
        id: finder

        // Candidates are passed as arguments, never spliced into the script.
        command: ["sh", "-c", 'for f in "$@"; do [ -r "$f" ] && { printf %s "$f"; exit 0; }; done', "sh"].concat(root.avatarCandidates)

        stdout: StdioCollector {
            onStreamFinished: root.avatar = text.trim()
        }
    }
}
