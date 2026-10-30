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

    readonly property real volumeStep: 0.02

    /*
     * Where the volume is going, while keys are being held. The real volume comes
     * back from the audio server a moment after it is set, so a held key that read
     * it each time would keep working from a stale value: several presses landing
     * on the same target, or stepping from where it was rather than where it is
     * going. The pending target carries on from itself until the presses stop.
     */
    property real volumeTarget: 0
    property bool volumeHeld: false

    function nudgeVolume(delta) {
        const base = root.volumeHeld ? root.volumeTarget : Audio.volume;
        root.volumeTarget = Math.max(0, Math.min(1, base + delta));
        root.volumeHeld = true;
        volumeRest.restart();
        Audio.setVolume(root.volumeTarget);
        Osd.volume(root.volumeTarget, false);
    }

    Timer {
        id: volumeRest

        interval: 450
        onTriggered: root.volumeHeld = false
    }
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
            root.nudgeVolume(root.volumeStep);
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "volumeDown"
        onPressed: root.nudgeVolume(-root.volumeStep)
    }

    GlobalShortcut {
        appid: "stratum"
        name: "volumeMute"
        onPressed: {
            Osd.volume(Audio.volume, !Audio.muted);
            Audio.toggleMuted();
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "micMute"
        onPressed: {
            Osd.mic(!Audio.sourceMuted);
            Audio.toggleSourceMuted();
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "brightnessUp"
        onPressed: {
            Brightness.step(root.brightnessStep);
            Osd.brightness(Brightness.value + root.brightnessStep);
        }
    }

    GlobalShortcut {
        appid: "stratum"
        name: "brightnessDown"
        onPressed: {
            Brightness.step(-root.brightnessStep);
            Osd.brightness(Brightness.value - root.brightnessStep);
        }
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
