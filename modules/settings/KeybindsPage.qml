pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs.theme

/*
 * The keys, as a keyboard.
 *
 * Every key is drawn where it sits and outlined by what is on it: white when
 * something is bound, the accent when two binds share a combination (Hyprland
 * fires both, which is rarely meant), and faint when it is free. A small dot
 * marks a key bound under more than one combination. Hovering a key lists what it
 * does; clicking one opens it to edit.
 *
 * Binds from your own config are shown and never touched. The shell's own —
 * keys pointed at its actions — can be added and removed here, and are written to
 * the stratum-binds file your config loads.
 */
Flickable {
    id: page

    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    property string size: "100%"
    // Which modifier combination the colours describe: any, or one exactly.
    property string filter: "any"
    property string hovered: ""
    property string selected: ""
    readonly property string shown: page.selected.length > 0 ? page.selected : page.hovered

    // The combination being made for the selected key.
    property var pendingMods: ["SUPER"]
    property string pendingAction: ""

    Component.onCompleted: Binds.refresh()

    // A key: label, Hyprland's name for it, position and size in key units.
    function k(label, key, x, y, w, h) {
        return { label: label, key: key, x: x, y: y, w: w ?? 1, h: h ?? 1 };
    }

    function row(labels, keys, x, y) {
        return labels.map((l, i) => page.k(l, keys[i], x + i, y));
    }

    readonly property var layout: {
        const keys = [];
        const f = page.size === "60%" ? -1.5 : 0;
        if (page.size !== "60%") {
            keys.push(page.k("Esc", "Escape", 0, 0));
            ["F1", "F2", "F3", "F4"].forEach((n, i) => keys.push(page.k(n, n, 2 + i, 0)));
            ["F5", "F6", "F7", "F8"].forEach((n, i) => keys.push(page.k(n, n, 6.5 + i, 0)));
            ["F9", "F10", "F11", "F12"].forEach((n, i) => keys.push(page.k(n, n, 11 + i, 0)));
        }
        const y = 1.5 + f;
        keys.push(page.k(page.size === "60%" ? "Esc" : "`", page.size === "60%" ? "Escape" : "grave", 0, y));
        "1234567890".split("").forEach((n, i) => keys.push(page.k(n, n, 1 + i, y)));
        keys.push(page.k("-", "minus", 11, y), page.k("=", "equal", 12, y), page.k("Back", "BackSpace", 13, y, 2));
        keys.push(page.k("Tab", "Tab", 0, y + 1, 1.5));
        "QWERTYUIOP".split("").forEach((n, i) => keys.push(page.k(n, n, 1.5 + i, y + 1)));
        keys.push(page.k("[", "bracketleft", 11.5, y + 1), page.k("]", "bracketright", 12.5, y + 1), page.k("\\", "backslash", 13.5, y + 1, 1.5));
        keys.push(page.k("Caps", "Caps_Lock", 0, y + 2, 1.75));
        "ASDFGHJKL".split("").forEach((n, i) => keys.push(page.k(n, n, 1.75 + i, y + 2)));
        keys.push(page.k(";", "semicolon", 10.75, y + 2), page.k("'", "apostrophe", 11.75, y + 2), page.k("Enter", "Return", 12.75, y + 2, 2.25));
        keys.push(page.k("Shift", "Shift_L", 0, y + 3, 2.25));
        "ZXCVBNM".split("").forEach((n, i) => keys.push(page.k(n, n, 2.25 + i, y + 3)));
        keys.push(page.k(",", "comma", 9.25, y + 3), page.k(".", "period", 10.25, y + 3), page.k("/", "slash", 11.25, y + 3), page.k("Shift", "Shift_R", 12.25, y + 3, 2.75));
        keys.push(page.k("Ctrl", "Control_L", 0, y + 4, 1.25), page.k("Super", "Super_L", 1.25, y + 4, 1.25), page.k("Alt", "Alt_L", 2.5, y + 4, 1.25),
            page.k("Space", "space", 3.75, y + 4, 6.25), page.k("Alt", "Alt_R", 10, y + 4, 1.25), page.k("Super", "Super_R", 11.25, y + 4, 1.25),
            page.k("Menu", "Menu", 12.5, y + 4, 1.25), page.k("Ctrl", "Control_R", 13.75, y + 4, 1.25));
        if (page.size !== "60%") {
            keys.push(page.k("Prt", "Print", 15.5, 0), page.k("Scr", "Scroll_Lock", 16.5, 0), page.k("Pau", "Pause", 17.5, 0));
            keys.push(page.k("Ins", "Insert", 15.5, y), page.k("Home", "Home", 16.5, y), page.k("PgU", "Prior", 17.5, y));
            keys.push(page.k("Del", "Delete", 15.5, y + 1), page.k("End", "End", 16.5, y + 1), page.k("PgD", "Next", 17.5, y + 1));
            keys.push(page.k("↑", "Up", 16.5, y + 3), page.k("←", "Left", 15.5, y + 4), page.k("↓", "Down", 16.5, y + 4), page.k("→", "Right", 17.5, y + 4));
        }
        if (page.size === "100%") {
            keys.push(page.k("Num", "Num_Lock", 19, y), page.k("/", "KP_Divide", 20, y), page.k("*", "KP_Multiply", 21, y), page.k("-", "KP_Subtract", 22, y));
            keys.push(page.k("7", "KP_7", 19, y + 1), page.k("8", "KP_8", 20, y + 1), page.k("9", "KP_9", 21, y + 1), page.k("+", "KP_Add", 22, y + 1, 1, 2));
            keys.push(page.k("4", "KP_4", 19, y + 2), page.k("5", "KP_5", 20, y + 2), page.k("6", "KP_6", 21, y + 2));
            keys.push(page.k("1", "KP_1", 19, y + 3), page.k("2", "KP_2", 20, y + 3), page.k("3", "KP_3", 21, y + 3), page.k("Ent", "KP_Enter", 22, y + 3, 1, 2));
            keys.push(page.k("0", "KP_0", 19, y + 4, 2), page.k(".", "KP_Decimal", 21, y + 4));
        }
        // The keys laptops and media keyboards add, in a row of their own.
        const m = y + 5.5;
        [["prev", "XF86AudioPrev"], ["play", "XF86AudioPlay"], ["next", "XF86AudioNext"], ["mute", "XF86AudioMute"],
            ["vol −", "XF86AudioLowerVolume"], ["vol +", "XF86AudioRaiseVolume"], ["mic", "XF86AudioMicMute"],
            ["bri −", "XF86MonBrightnessDown"], ["bri +", "XF86MonBrightnessUp"]]
            .forEach(([l, n], i) => keys.push(page.k(l, n, i * 1.25, m, 1.25)));
        return keys;
    }

    readonly property real unitsWide: page.size === "100%" ? 23 : (page.size === "75%" ? 18.5 : 15)
    readonly property real unitsTall: page.size === "60%" ? 6.5 : 8
    readonly property real unit: Math.min(46, page.width / page.unitsWide)

    // What a key's outline says, for the current filter.
    function lookOf(key) {
        let binds = Binds.forKey(key);
        if (page.filter !== "any") {
            const m = page.filter === "none" ? 0 : Binds.maskOf([page.filter.toUpperCase()]);
            binds = binds.filter(b => b.mask === m);
        }
        if (binds.length === 0)
            return "free";
        const masks = binds.map(b => b.mask);
        return new Set(masks).size < masks.length ? "conflict" : "bound";
    }

    function describe(b) {
        if (b.stratum)
            return Binds.actionLabel(b.arg.slice("stratum:".length));
        if (b.description.length > 0)
            return b.description;
        if (b.dispatcher === "__lua")
            return "a Lua function in your config";
        return `${b.dispatcher} ${b.arg}`.trim();
    }

    Column {
        id: body

        width: page.width
        spacing: Theme.space(3)

        Row {
            width: parent.width
            spacing: Theme.space(3)

            Column {
                width: parent.width - sizes.width - Theme.space(3)
                spacing: 2

                SectionLabel {
                    text: "keybinds"
                }

                Text {
                    text: "Hover a key to see what it does. Click one to change it."
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }
            }

            Segmented {
                id: sizes

                model: ["60%", "75%", "100%"]
                current: ["60%", "75%", "100%"].indexOf(page.size)
                onPicked: index => page.size = ["60%", "75%", "100%"][index]
            }
        }

        Segmented {
            model: ["any", "none", "super", "shift", "ctrl", "alt"]
            current: ["any", "none", "super", "shift", "ctrl", "alt"].indexOf(page.filter)
            onPicked: index => page.filter = ["any", "none", "super", "shift", "ctrl", "alt"][index]
        }

        // The keyboard.
        Item {
            width: page.unitsWide * page.unit
            height: page.unitsTall * page.unit

            Repeater {
                model: page.layout

                Rectangle {
                    id: key

                    required property var modelData

                    readonly property string look: page.lookOf(key.modelData.key)
                    readonly property bool chosen: page.selected === key.modelData.key
                    readonly property int combos: new Set(Binds.forKey(key.modelData.key).map(b => b.mask)).size

                    x: key.modelData.x * page.unit
                    y: key.modelData.y * page.unit
                    width: key.modelData.w * page.unit - 4
                    height: key.modelData.h * page.unit - 4
                    radius: 7
                    color: key.chosen ? Theme.fg : (hover.hovered ? Theme.surfaceTop : Theme.surfaceHi)
                    border.width: key.look === "free" ? 1 : 1.5
                    border.color: key.look === "conflict" ? Theme.accent : (key.look === "bound" ? Theme.fgBright : Theme.line)

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.micro
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: key.modelData.label
                        color: key.chosen ? Theme.bg : (key.look === "free" ? Theme.fgFaint : Theme.fg)
                        font.family: Theme.fontUi
                        font.pixelSize: Math.max(9, Math.min(13, page.unit * 0.3))
                        font.weight: Font.Medium
                        renderType: Text.NativeRendering
                    }

                    // On more than one combination.
                    Rectangle {
                        visible: key.combos > 1
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 4
                        width: 4
                        height: 4
                        radius: 2
                        color: key.chosen ? Theme.bg : Theme.fgBright
                    }

                    HoverHandler {
                        id: hover

                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered)
                                page.hovered = key.modelData.key;
                            else if (page.hovered === key.modelData.key)
                                page.hovered = "";
                        }
                    }

                    TapHandler {
                        onTapped: {
                            page.selected = page.selected === key.modelData.key ? "" : key.modelData.key;
                            page.pendingAction = "";
                        }
                    }
                }
            }
        }

        Text {
            text: {
                const conflicts = new Set(Binds.all.filter(b => Binds.conflicted(b.key)).map(b => b.k)).size;
                const base = "white: bound  ·  red: two binds on one combination  ·  faint: free";
                return conflicts > 0 ? `${base}  ·  ${conflicts} ${conflicts === 1 ? "key" : "keys"} with a conflict` : base;
            }
            color: Theme.fgDim
            font.family: Theme.fontUi
            font.pixelSize: 12
            renderType: Text.NativeRendering
        }

        // What the hovered or chosen key does, and the editor for a chosen one.
        Rectangle {
            width: parent.width
            height: inspector.implicitHeight + Theme.space(4) * 2
            radius: Theme.rTile
            color: Theme.surfaceHi
            visible: page.shown.length > 0

            Column {
                id: inspector

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.space(4)
                spacing: Theme.space(2)

                SectionLabel {
                    text: page.layout.find(k => k.key === page.shown)?.label ?? page.shown
                    color: Theme.fgBright
                }

                Text {
                    visible: Binds.forKey(page.shown).length === 0
                    text: "Nothing is bound to this key."
                    color: Theme.fgDim
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: Binds.forKey(page.shown)

                    Row {
                        id: bindRow

                        required property var modelData

                        readonly property bool mine: Binds.isOwn(bindRow.modelData.mods, page.shown)

                        spacing: Theme.space(3)

                        Text {
                            width: 170
                            text: Binds.combo(bindRow.modelData.mods, page.layout.find(k => k.key === page.shown)?.label ?? page.shown)
                            color: Theme.fg
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }

                        Text {
                            width: 280
                            elide: Text.ElideRight
                            text: page.describe(bindRow.modelData)
                            color: Theme.fgBright
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            renderType: Text.NativeRendering
                        }

                        SectionLabel {
                            text: bindRow.mine ? "stratum" : "your config"
                            color: Theme.fgDim
                        }

                        Text {
                            visible: bindRow.mine && page.selected.length > 0
                            text: "remove"
                            color: removeHover.hovered ? Theme.accent : Theme.fgDim
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            renderType: Text.NativeRendering

                            HoverHandler {
                                id: removeHover

                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: Binds.removeOwn(bindRow.modelData.mods, page.selected)
                            }
                        }
                    }
                }

                // Binding a new combination on this key.
                Column {
                    visible: page.selected.length > 0
                    width: parent.width
                    spacing: Theme.space(2)
                    topPadding: Theme.space(2)

                    SectionLabel {
                        text: "add a bind"
                        color: Theme.fgDim
                    }

                    Row {
                        spacing: Theme.space(1)

                        Repeater {
                            model: ["SUPER", "SHIFT", "CTRL", "ALT"]

                            Rectangle {
                                id: modChip

                                required property string modelData

                                readonly property bool on: page.pendingMods.includes(modChip.modelData)

                                width: modLabel.implicitWidth + Theme.space(4)
                                height: 30
                                radius: 15
                                color: modChip.on ? Theme.fg : Theme.surfaceTop

                                SectionLabel {
                                    id: modLabel

                                    anchors.centerIn: parent
                                    text: modChip.modelData
                                    color: modChip.on ? Theme.bg : Theme.fg
                                }

                                TapHandler {
                                    onTapped: page.pendingMods = modChip.on
                                        ? page.pendingMods.filter(m => m !== modChip.modelData)
                                        : page.pendingMods.concat([modChip.modelData])
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: Theme.space(2)
                            text: `+ ${page.layout.find(k => k.key === page.selected)?.label ?? page.selected}`
                            color: Theme.fg
                            font.family: Theme.fontUi
                            font.pixelSize: 13
                            font.weight: Font.Medium
                            renderType: Text.NativeRendering
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: Theme.space(1)

                        Repeater {
                            model: Binds.actions

                            Rectangle {
                                id: actionChip

                                required property var modelData

                                readonly property bool on: page.pendingAction === actionChip.modelData.name

                                width: actionLabel.implicitWidth + Theme.space(4)
                                height: 28
                                radius: 14
                                color: actionChip.on ? Theme.fg : (actionHover.hovered ? Theme.surfaceTop : "transparent")
                                border.width: 1
                                border.color: Theme.line

                                Text {
                                    id: actionLabel

                                    anchors.centerIn: parent
                                    text: actionChip.modelData.label
                                    color: actionChip.on ? Theme.bg : Theme.fgBright
                                    font.family: Theme.fontUi
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }

                                HoverHandler {
                                    id: actionHover

                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: page.pendingAction = actionChip.modelData.name
                                }
                            }
                        }
                    }

                    Row {
                        spacing: Theme.space(3)

                        ActionButton {
                            text: "bind"
                            width: 96
                            enabled: page.pendingAction.length > 0
                            onClicked: {
                                Binds.addOwn(page.pendingMods, page.selected, page.pendingAction);
                                page.pendingAction = "";
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property var taken: Binds.forKey(page.selected).filter(b => b.mask === Binds.maskOf(page.pendingMods) && !b.stratum)
                            visible: taken.length > 0
                            text: `${Binds.combo(page.pendingMods, "key")} is already used by your config — both would fire.`
                            color: Theme.accent
                            font.family: Theme.fontUi
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }

        Row {
            spacing: Theme.space(3)

            ActionButton {
                text: "reload"
                width: 96
                onClicked: Binds.refresh()
            }

            ActionButton {
                text: "restore defaults"
                width: 150
                onClicked: Binds.resetOwn()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Binds.error.length > 0
                text: Binds.error
                color: Theme.accent
                font.family: Theme.fontUi
                font.pixelSize: 12
                renderType: Text.NativeRendering
            }
        }
    }
}
