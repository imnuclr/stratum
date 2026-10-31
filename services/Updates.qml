pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

/*
 * Whether a newer Stratum is waiting, and getting it.
 *
 * Stratum runs straight from its git folder, so a version is a commit and an
 * update is a fast-forward pull. Checked a while after starting and every six
 * hours (Settings → Updates can turn that off); a notification says when
 * something new has arrived, once per new version.
 */
Singleton {
    id: root

    readonly property string dir: Quickshell.shellPath("")

    property string version: ""
    property string date: ""
    property string branch: ""
    // What is waiting, newest first: [{ hash, title, when }].
    property var waiting: []
    property bool dirty: false
    property string state: "idle"   // idle, checking, updating, failed
    property string error: ""
    property string checkedAt: ""

    readonly property int count: root.waiting.length
    readonly property bool automatic: Config.get("updates.check", true)
    // Hours between checks: Settings → Updates.
    readonly property real everyHours: Config.get("updates.everyHours", 6)

    function check() {
        if (root.state === "checking" || root.state === "updating")
            return;
        root.state = "checking";
        root.error = "";
        probe.running = true;
    }

    /*
     * The notification, with Stratum's own update mark as its icon, and
     * clicking it opening Settings on Updates. notify-send waits for the click
     * and prints the action, which is how the click gets back here.
     */
    function announce(body) {
        notifier.command = ["notify-send", "-a", "Stratum", "-i", Quickshell.shellPath("assets/icons/update.svg"),
            "--action=default=Open updates", "Stratum update ready", body];
        notifier.running = true;
    }

    Process {
        id: notifier

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "default") {
                    Shell.settingsPage = "updates";
                    Shell.open("settings");
                }
            }
        }
    }

    function update() {
        if (root.state === "updating" || root.dirty)
            return;
        root.state = "updating";
        puller.running = true;
    }

    Process {
        id: probe

        command: ["sh", "-c", `
            cd "$1" || exit 1
            echo "version=$(git log -1 --format='%h')"
            echo "date=$(git log -1 --format='%cs')"
            echo "branch=$(git branch --show-current)"
            [ -n "$(git status --porcelain --untracked-files=no)" ] && echo "dirty=1"
            git fetch -q 2>/tmp/stratum-fetch.err || { echo "error=$(head -n1 /tmp/stratum-fetch.err)"; exit 0; }
            git log --format='commit=%h|%s|%cr' HEAD..@{u} 2>/dev/null`, "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                const commits = [];
                let dirty = false;
                for (const line of text.split("\n")) {
                    const at = line.indexOf("=");
                    if (at < 0)
                        continue;
                    const k = line.slice(0, at);
                    const v = line.slice(at + 1);
                    if (k === "version") root.version = v;
                    else if (k === "date") root.date = v;
                    else if (k === "branch") root.branch = v;
                    else if (k === "dirty") dirty = true;
                    else if (k === "error") root.error = v;
                    else if (k === "commit") {
                        const [hash, title, when] = v.split("|");
                        commits.push({ hash: hash, title: title, when: when });
                    }
                }
                root.dirty = dirty;
                const before = root.count;
                root.waiting = commits;
                root.checkedAt = Qt.formatTime(new Date(), "HH:mm");
                root.state = root.error.length > 0 ? "failed" : "idle";
                // Said once per new arrival, not at every check.
                const told = Config.get("updates.told", "");
                if (commits.length > 0 && commits[0].hash !== told && commits.length > before) {
                    Config.set("updates.told", commits[0].hash);
                    root.announce(commits.length === 1 ? commits[0].title : `${commits.length} changes, newest: ${commits[0].title}`);
                }
            }
        }
    }

    Process {
        id: puller

        command: ["sh", "-c", `cd "$1" && git pull --ff-only -q 2>&1 | tail -n 3`, "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: root.error = text.trim()
        }

        onExited: code => {
            if (code !== 0) {
                root.state = "failed";
                return;
            }
            // A new copy of the shell, started apart from this one, which it
            // replaces.
            Quickshell.execDetached(["setsid", "-f", "sh", "-c", "sleep 0.4; stratum restart >/dev/null 2>&1 || (pkill -x qs; qs -c stratum >/dev/null 2>&1 &)"]);
        }
    }

    Timer {
        // First check a little after starting, then every six hours.
        running: root.automatic
        repeat: true
        triggeredOnStart: false
        interval: root.checkedAt.length === 0 ? 90000 : Math.max(0.25, root.everyHours) * 3600000
        onTriggered: root.check()
    }

    Component.onCompleted: {
        // What is installed is known at once; checking waits for the timer.
        versionOnly.running = true;
    }

    Process {
        id: versionOnly

        command: ["sh", "-c", `cd "$1" && git log -1 --format='%h %cs' && git branch --show-current`, "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const [v, d] = (lines[0] ?? "").split(" ");
                root.version = v ?? "";
                root.date = d ?? "";
                root.branch = lines[1] ?? "";
            }
        }
    }
}
