import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

/*
 * Keys the shell owns, registered as Hyprland global shortcuts under the
 * "stratum" appid. Hyprland binds a key to `global, stratum:<name>` and the
 * handler here runs — so the shell declares what it responds to and the config
 * only says which key reaches it.
 *
 * Volume and brightness are handled here rather than left to wpctl in a bind,
 * so the shell's own sliders and indicators move with the keys instead of
 * finding out later.
 */
Item {
    id: root

    readonly property real volumeStep: 0.05
    readonly property real brightnessStep: 0.05

    GlobalShortcut {
        appid: "stratum"
        name: "mediaToggle"
        onPressed: Media.playPause()
    }

    GlobalShortcut {
        appid: "stratum"
        name: "mediaNext"
        onPressed: Media.next()
    }

    GlobalShortcut {
        appid: "stratum"
        name: "mediaPrev"
        onPressed: Media.previous()
    }

    GlobalShortcut {
        appid: "stratum"
        name: "volumeUp"
        // Raising the volume unmutes: pressing up on a muted sink and hearing
        // nothing is the wrong answer to the question being asked.
        onPressed: {
            if (Audio.muted)
                Audio.setMuted(false);
            Audio.setVolume(Audio.volume + root.volumeStep);
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "volumeDown"
        onPressed: Audio.setVolume(Audio.volume - root.volumeStep)
    }

    GlobalShortcut {
        appid: "stratum"
        name: "volumeMute"
        onPressed: Audio.toggleMuted()
    }

    GlobalShortcut {
        appid: "stratum"
        name: "micMute"
        onPressed: Audio.toggleSourceMuted()
    }

    GlobalShortcut {
        appid: "stratum"
        name: "brightnessUp"
        onPressed: Brightness.step(root.brightnessStep)
    }

    GlobalShortcut {
        appid: "stratum"
        name: "brightnessDown"
        onPressed: Brightness.step(-root.brightnessStep)
    }

    GlobalShortcut {
        appid: "stratum"
        name: "screenshot"
        onPressed: {
            Diag.log("shortcut", "screenshot pressed");
            Screenshot.screen();
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "screenshotRegion"
        onPressed: {
            Diag.log("shortcut", "screenshotRegion pressed");
            Screenshot.region();
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "screenshotEdit"
        onPressed: Screenshot.annotate()
    }

    GlobalShortcut {
        appid: "stratum"
        name: "record"
        onPressed: Toggles.toggleRecording()
    }

    GlobalShortcut {
        appid: "stratum"
        name: "recordRegion"
        onPressed: {
            Diag.log("shortcut", "recordRegion pressed");
            if (Toggles.recording)
                Toggles.stopRecording();
            else
                Toggles.recordRegion();
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "deck"
        onPressed: Shell.toggle("dashboard")
    }

    GlobalShortcut {
        appid: "stratum"
        name: "control"
        onPressed: Shell.toggle("control")
    }

    GlobalShortcut {
        appid: "stratum"
        name: "session"
        onPressed: Shell.toggle("session")
    }
}
