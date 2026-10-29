import QtQuick
import Quickshell
import qs.config
import qs.modules.bar.vertical

/*
 * One bar per monitor. Every visual value is read through Config.forMonitor so a
 * display can override size, layout or which items it shows.
 *
 * bar.orientation picks the shape. The two are separate windows rather than one
 * that rotates: a layer surface anchored to the top and one anchored to the left
 * differ in which axis is exclusive, which axis the popouts clamp on, and how
 * every group inside is laid out, so sharing one implementation would be a
 * branch at nearly every line.
 */
Variants {
    model: Quickshell.screens

    Loader {
        required property ShellScreen modelData

        readonly property bool vertical: Config.forMonitor(modelData.name, "bar.orientation", "vertical") === "vertical"

        active: true
        sourceComponent: vertical ? verticalBar : horizontalBar

        Component {
            id: verticalBar

            VerticalBarWindow {
                monitor: modelData
            }
        }

        Component {
            id: horizontalBar

            BarWindow {
                monitor: modelData
            }
        }
    }
}
