pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

/*
 * Light or dark, decided by the wallpaper.
 *
 * The shell had a dark/light toggle and a wallpaper-derived palette, but the two
 * never spoke: putting up a bright picture recoloured everything and left the
 * surfaces black, so dark tiles sat on a white sky. The hues followed the
 * wallpaper and the tone did not.
 *
 * The measurement is the mean of the picture reduced to a 64px grey thumbnail.
 * Mean rather than anything cleverer because the question is only which side of
 * the middle the whole image sits on, and a thumbnail answers that for the cost
 * of one short process per wallpaper.
 *
 * It goes through Toggles.setDark rather than writing Theme.dark directly, so
 * the GTK colour-scheme key moves with it — otherwise the shell would turn light
 * while every application stayed dark.
 */
Singleton {
    id: root

    readonly property bool enabled: Config.get("theme.followWallpaper", true)
    // Above this mean, the picture counts as light. Configurable because where
    // the middle sits is a matter of taste, not of fact.
    readonly property real threshold: Config.get("theme.lightThreshold", 0.5)

    // The first display's picture stands for the desktop when they differ, the
    // same way the palette treats them.
    readonly property string image: Wallpaper.forMonitor(Quickshell.screens[0]?.name ?? "")

    // Last measurement, for the settings page and for anyone debugging a picture
    // that lands on the wrong side.
    property real luminance: -1
    property bool available: true

    // Which image the running process is for, so a late answer cannot be applied
    // to a wallpaper that has since changed.
    property string measuring: ""

    onImageChanged: root.measure()
    onEnabledChanged: root.measure()
    Component.onCompleted: root.measure()

    function measure() {
        if (!root.enabled || !root.available || root.image.length === 0)
            return;
        if (probe.running)
            return;
        root.measuring = root.image;
        probe.command = ["magick", root.image, "-resize", "64x64!",
            "-colorspace", "gray", "-format", "%[fx:mean]", "info:"];
        probe.running = true;
    }

    Process {
        id: probe

        onExited: code => {
            // No ImageMagick, or it could not read the picture: stop trying and
            // leave whatever the person last chose alone.
            if (code !== 0)
                root.available = false;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                // The wallpaper changed while this was running; its answer is
                // about the wrong picture.
                if (root.measuring !== root.image)
                    return;
                const mean = parseFloat(text);
                if (!isFinite(mean))
                    return;
                root.luminance = mean;
                Toggles.setDark(mean < root.threshold);
            }
        }
    }
}
