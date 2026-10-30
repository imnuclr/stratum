import QtQuick
import Quickshell
import Quickshell.Services.Pam

/*
 * What has been typed, and what the system made of it.
 *
 * One of these is shared by every screen's lock surface, so typing on either
 * monitor fills the same box on both and there is only ever one PAM
 * conversation in flight.
 */
Scope {
    id: root

    // idle -> checking -> success | failed | error | maxtries
    property string phase: "idle"
    property string buffer: ""
    // PAM's own words when an account is locked out and for how long.
    property string notice: ""

    readonly property int length: root.buffer.length

    signal unlocked
    // A wrong attempt, for the box to shake at.
    signal rejected

    function reset() {
        root.buffer = "";
        root.notice = "";
        root.phase = "idle";
        settle.stop();
    }

    function handleKey(event) {
        // Typing is ignored while an answer is awaited, and once one has arrived.
        if (root.phase === "checking" || root.phase === "success" || root.phase === "maxtries")
            return;

        // Starting again clears the last failure.
        if (root.phase === "failed" || root.phase === "error")
            root.phase = "idle";

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.buffer.length === 0)
                return;
            root.phase = "checking";
            pam.start();
        } else if ((event.key === Qt.Key_Backspace || event.key === Qt.Key_U) && (event.modifiers & Qt.ControlModifier)) {
            root.buffer = "";
        } else if (event.key === Qt.Key_Backspace) {
            root.buffer = root.buffer.slice(0, -1);
        } else if (event.key === Qt.Key_Escape) {
            root.buffer = "";
        } else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text)) {
            root.buffer += event.text;
        }
    }

    PamContext {
        id: pam

        config: "stratum"
        configDirectory: Quickshell.shellPath("assets/pam.d")

        onMessageChanged: {
            if (message.startsWith("The account is locked"))
                root.notice = message;
            else if (root.notice.length > 0 && message.endsWith(" left to unlock)"))
                root.notice += "\n" + message;
        }

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            // The buffer stays until the answer comes back, so the dots hold
            // while it is checked instead of vanishing the moment Enter is hit.
            respond(root.buffer);
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.phase = "success";
                root.unlocked();
                return;
            }

            root.buffer = "";
            if (result === PamResult.MaxTries)
                root.phase = "maxtries";
            else if (result === PamResult.Error)
                root.phase = "error";
            else
                root.phase = "failed";

            root.rejected();
            settle.restart();
        }
    }

    // A lockout is not permanent from here: offer the box again after a while and
    // let PAM say no if it is still locked.
    Timer {
        id: settle

        interval: 15000
        onTriggered: {
            if (root.phase === "maxtries")
                root.phase = "idle";
        }
    }
}
