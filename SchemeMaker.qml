import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "ColorUtil.js" as CU

// /scheme-maker — build a colour scheme with live preview on the real shell, then save it.
// ↑↓ select row · ←/→ hue (Shift = saturation, Ctrl = lightness) · Enter edits the hex / runs an action ·
// Ctrl+S saves · Esc cancels (nothing is kept unless you save).
PanelWindow {
    id: win

    property bool open: false
    property real progress: open ? 1 : 0
    Behavior on progress { NumberAnimation { duration: Theme.dur(280); easing.type: Easing.OutCubic } }
    onOpenChanged: Popups.report("schememaker", open)
    Connections {
        target: Popups
        function onCloseOthers(except) { if (except !== "schememaker" && win.open) win.hide(true) }
        function onCloseAll() { if (win.open) win.hide(true) }
    }

    property int index: 1
    property string originalTheme: ""
    property bool saving: false
    property bool lightBase: false
    property string themeName: "my-scheme"
    property var cols: ({ bg: "#000000", surface: "#111111", fg: "#ffffff", dim: "#888888", accent: "#ff3366", accent2: "#8866ff", warn: "#ffaa33" })
    property real opacityV: 0.94
    property real shadowV: 0.6
    // working HSL of the selected colour (kept separately so dragging doesn't lose the hue of grey colours)
    property real hh: 0
    property real ss: 0
    property real ll: 0

    readonly property string userDir: Quickshell.env("HOME") + "/.config/lovelyrice/themes"
    readonly property var rows: [
        { type: "name",   label: "Name" },
        { type: "color",  key: "bg",      label: "Background" },
        { type: "color",  key: "surface", label: "Surface" },
        { type: "color",  key: "fg",      label: "Text" },
        { type: "color",  key: "dim",     label: "Dim text" },
        { type: "color",  key: "accent",  label: "Accent" },
        { type: "color",  key: "accent2", label: "Accent 2" },
        { type: "color",  key: "warn",    label: "Warning" },
        { type: "slider", key: "opacity", label: "Panel opacity", min: 0.5, max: 1.0, step: 0.02 },
        { type: "slider", key: "shadow",  label: "Shadow",        min: 0.0, max: 1.0, step: 0.05 },
        { type: "toggle", key: "light",   label: "Light base (for Generate / Random)" },
        { type: "action", id: "gen",      label: "Generate palette from Accent" },
        { type: "action", id: "random",   label: "Random palette" },
        { type: "action", id: "reset",    label: "Reset to current theme" },
        { type: "action", id: "save",     label: "Save theme" }
    ]
    readonly property var cur: rows[index]
    readonly property bool onColor: cur && cur.type === "color"

    // ---------- data ----------
    function hexOf(c) { return CU.normalizeHex(String(c)) || "#000000" }
    function loadCurrent() {
        cols = { bg: hexOf(Theme.bg), surface: hexOf(Theme.surface), fg: hexOf(Theme.fg), dim: hexOf(Theme.dim),
                 accent: hexOf(Theme.accent), accent2: hexOf(Theme.accent2), warn: hexOf(Theme.warn) }
        opacityV = Theme.opacity
        shadowV = Theme.shadowOpacity
        loadHsl()
    }
    function applyLive() {
        Theme.applyData({ colors: cols, opacity: opacityV, shadow: shadowV, wallpaper: Theme.themeWallpaper })
    }
    function setColor(key, hex) {
        const c = Object.assign({}, cols)
        c[key] = hex
        cols = c
        applyLive()
    }
    function loadHsl() {
        if (!onColor) return
        const v = CU.hexToHsl(cols[cur.key])
        hh = v[0]; ss = v[1]; ll = v[2]
        syncField()
    }
    function setHsl(h, s, l) {
        hh = ((h % 360) + 360) % 360; ss = CU.clamp(s, 0, 100); ll = CU.clamp(l, 0, 100)
        if (onColor) setColor(cur.key, CU.hslToHex(hh, ss, ll))
        syncField()
    }
    function syncField() {
        if (field.activeFocus) return
        field.text = !cur ? "" : (cur.type === "name" ? themeName : (cur.type === "color" ? cols[cur.key] : ""))
    }
    function slug() { return themeName.toLowerCase().trim().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") }
    function useColors(c) { cols = c; applyLive(); loadHsl() }

    // ---------- actions ----------
    function runAction(id) {
        if (id === "gen") useColors(CU.generate(cols.accent, lightBase))
        else if (id === "random") useColors(CU.generate(CU.randomAccent(lightBase), lightBase))
        else if (id === "reset") { Theme.select(originalTheme); loadCurrent() }
        else if (id === "save") save()
    }
    function save() {
        const s = slug()
        if (s === "") { Quickshell.execDetached(["notify-send", "-a", "LovelyRice", "Give the scheme a name first"]); return }
        const obj = { name: s, colors: cols, font: Theme.font, opacity: Math.round(opacityV * 100) / 100, shadow: Math.round(shadowV * 100) / 100 }
        saving = true
        saver.command = ["sh", "-c", 'mkdir -p "$1" && printf %s "$2" > "$1/$3.json"', "sh", userDir, JSON.stringify(obj, null, 2), s]
        saver.running = true
    }
    Process {
        id: saver
        onExited: code => {
            win.saving = false
            if (code !== 0) { Quickshell.execDetached(["notify-send", "-a", "LovelyRice", "Couldn't save the scheme"]); return }
            const s = win.slug()
            Theme.registerUser(s, win.userDir + "/" + s + ".json")
            Theme.select(s)
            Theme.save()
            Theme.rescan()
            Quickshell.execDetached(["notify-send", "-a", "LovelyRice", "Scheme saved", s + "  (now active)"])
            win.hide(false)
        }
    }

    function show() {
        Popups.claim("schememaker")
        originalTheme = Theme.name
        themeName = Theme.name + "-custom"
        index = 5      // start on Accent: the colour most people want to change first
        loadCurrent()
        open = true
        keys.forceActiveFocus()
    }
    function hide(revert) {
        if (revert && !saving) Theme.select(originalTheme)
        open = false
        field.focus = false
    }

    // ---------- keyboard ----------
    function move(d) { index = (index + d + rows.length) % rows.length; loadHsl(); syncField() }
    function adjust(dir, mods) {
        const r = cur
        if (r.type === "color") {
            if (mods & Qt.ControlModifier) setHsl(hh, ss, ll + dir * 3)
            else if (mods & Qt.ShiftModifier) setHsl(hh, ss + dir * 4, ll)
            else setHsl(hh + dir * 6, ss, ll)
        } else if (r.type === "slider") {
            if (r.key === "opacity") opacityV = CU.clamp(Math.round((opacityV + dir * r.step) * 100) / 100, r.min, r.max)
            else shadowV = CU.clamp(Math.round((shadowV + dir * r.step) * 100) / 100, r.min, r.max)
            applyLive()
        } else if (r.type === "toggle") lightBase = !lightBase
    }
    function activate() {
        const r = cur
        if (r.type === "name" || r.type === "color") field.forceActiveFocus()
        else if (r.type === "toggle") lightBase = !lightBase
        else if (r.type === "action") runAction(r.id)
    }

    visible: progress > 0.001
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lovelyrice-schememaker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.25 * win.progress)     // light dim so the live preview stays visible
        MouseArea { anchors.fill: parent; onClicked: win.hide(true) }
    }

    Card {
        id: card
        width: 780
        height: Math.min(parent.height - 80, 560)
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2 + (1 - win.progress) * 20
        opacity: win.progress
        scale: 0.94 + 0.06 * win.progress
        transformOrigin: Item.Center
        radius: Theme.radius + 4
        color: Qt.alpha(Theme.bg, 0.97)
        borderColor: Qt.alpha(Theme.accent, 0.8)
        borderWidth: 2
        shadowY: 18

        MouseArea { anchors.fill: parent }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                const ctrl = e.modifiers & Qt.ControlModifier
                if (e.key === Qt.Key_Escape)                   win.hide(true)
                else if (ctrl && e.key === Qt.Key_S)           win.save()
                else if (e.key === Qt.Key_Down)                win.move(1)
                else if (e.key === Qt.Key_Up)                  win.move(-1)
                else if (e.key === Qt.Key_Right)               win.adjust(1, e.modifiers)
                else if (e.key === Qt.Key_Left)                win.adjust(-1, e.modifiers)
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) win.activate()
                else return
                e.accepted = true
            }
        }

        Text {
            x: 26; y: 18
            text: "Scheme maker"
            color: Theme.fg
            font { family: Theme.font; pixelSize: 20; bold: true }
        }
        Text {
            anchors { right: parent.right; rightMargin: 26; top: parent.top; topMargin: 24 }
            text: "changes preview live  ·  nothing is kept until you save"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 11 }
        }

        // ---------- left: rows ----------
        ListView {
            id: list
            x: 12; y: 60
            width: 330
            height: parent.height - 60 - 40
            clip: true
            model: win.rows
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: win.index
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: index === win.index
                width: ListView.view.width
                height: 38

                Rectangle {
                    anchors { fill: parent; topMargin: 2; bottomMargin: 2; leftMargin: 4; rightMargin: 4 }
                    radius: Theme.radiusSmall
                    color: row.sel ? Theme.surface : "transparent"
                    border.color: row.sel ? Qt.alpha(Theme.accent, 0.5) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.dur(150) } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { win.index = row.index; win.loadHsl(); win.syncField(); if (row.modelData.type !== "name" && row.modelData.type !== "color") win.activate() }
                }

                Rectangle {   // colour swatch
                    visible: row.modelData.type === "color"
                    x: 16; width: 22; height: 22; radius: 11
                    anchors.verticalCenter: parent.verticalCenter
                    color: row.modelData.type === "color" ? win.cols[row.modelData.key] : "transparent"
                    border.color: Qt.alpha(Theme.dim, 0.7)
                }
                Text {
                    visible: row.modelData.type !== "action"
                    x: row.modelData.type === "color" ? 48 : 20
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                    color: Theme.fg
                    font { family: Theme.font; pixelSize: 13 }
                }
                Text {   // value on the right
                    visible: row.modelData.type !== "action"
                    anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                    text: row.modelData.type === "name" ? win.themeName
                          : row.modelData.type === "color" ? win.cols[row.modelData.key]
                          : row.modelData.type === "toggle" ? (win.lightBase ? "on" : "off")
                          : (row.modelData.key === "opacity" ? Math.round(win.opacityV * 100) + "%" : Math.round(win.shadowV * 100) + "%")
                    color: Theme.dim
                    font { family: Theme.font; pixelSize: 12 }
                }
                Text {
                    visible: row.modelData.type === "action"
                    anchors.centerIn: parent
                    text: row.modelData.label
                    color: row.modelData.id === "save" ? Theme.accent : Theme.warn
                    font { family: Theme.font; pixelSize: 13; bold: row.modelData.id === "save" }
                }
            }
        }

        Rectangle {
            x: 358; y: 66; width: 1; height: parent.height - 66 - 50
            color: Qt.alpha(Theme.dim, 0.35)
        }

        // ---------- right: editor for the selected row ----------
        Item {
            id: detail
            x: 380; y: 64
            width: parent.width - 380 - 26
            height: parent.height - 64 - 50

            Text {
                text: win.cur ? win.cur.label : ""
                color: Theme.accent
                font { family: Theme.font; pixelSize: 12; bold: true }
            }

            Rectangle {   // big swatch
                visible: win.onColor
                y: 26; width: 84; height: 84; radius: Theme.radiusSmall + 4
                color: win.onColor ? win.cols[win.cur.key] : "transparent"
                border.color: Qt.alpha(Theme.dim, 0.7); border.width: 2
            }
            Rectangle {   // hex / name field
                id: fieldBox
                visible: win.onColor || (win.cur && win.cur.type === "name")
                x: win.onColor ? 100 : 0; y: win.onColor ? 26 : 26
                width: parent.width - x; height: 40
                radius: Theme.radiusSmall
                color: Theme.surface
                border.width: 2
                border.color: field.activeFocus ? Theme.accent : Qt.alpha(Theme.dim, 0.5)
                Behavior on border.color { ColorAnimation { duration: Theme.dur(150) } }
                TextInput {
                    id: field
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    font { family: Theme.font; pixelSize: 15 }
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    onTextEdited: {
                        if (win.cur.type === "name") win.themeName = text
                        else if (win.cur.type === "color") {
                            const hx = CU.normalizeHex(text)
                            if (hx !== "") {
                                win.setColor(win.cur.key, hx)
                                const v = CU.hexToHsl(hx); win.hh = v[0]; win.ss = v[1]; win.ll = v[2]
                            }
                        }
                    }
                    Keys.onPressed: e => {
                        if (e.key === Qt.Key_Escape || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                            keys.forceActiveFocus(); win.syncField(); e.accepted = true
                        }
                    }
                }
            }
            Text {
                visible: win.cur && win.cur.type === "name"
                y: 78; width: parent.width
                wrapMode: Text.WordWrap
                text: "Saved as ~/.config/lovelyrice/themes/" + (win.slug() || "name") + ".json and shown in /scheme."
                color: Theme.dim
                font { family: Theme.font; pixelSize: 11 }
            }

            Column {
                visible: win.onColor
                y: 128; width: parent.width; spacing: 4
                MiniSlider { width: parent.width; label: "Hue"; from: 0; to: 360; rainbow: true; value: win.hh
                             onMoved: v => win.setHsl(v, win.ss, win.ll) }
                MiniSlider { width: parent.width; label: "Saturation"; from: 0; to: 100; value: win.ss
                             c0: CU.hslToHex(win.hh, 0, win.ll); c1: CU.hslToHex(win.hh, 50, win.ll); c2: CU.hslToHex(win.hh, 100, win.ll)
                             onMoved: v => win.setHsl(win.hh, v, win.ll) }
                MiniSlider { width: parent.width; label: "Lightness"; from: 0; to: 100; value: win.ll
                             c0: "#000000"; c1: CU.hslToHex(win.hh, win.ss, 50); c2: "#ffffff"
                             onMoved: v => win.setHsl(win.hh, win.ss, v) }
            }

            Text {   // help for non-colour rows
                visible: win.cur && !win.onColor && win.cur.type !== "name"
                y: 28; width: parent.width
                wrapMode: Text.WordWrap
                color: Theme.dim
                font { family: Theme.font; pixelSize: 12 }
                text: !win.cur ? "" :
                      win.cur.type === "slider" ? "←/→ or drag to change. Opacity is how see-through the bar and popups are."
                    : win.cur.type === "toggle" ? "Switches Generate and Random between dark and light palettes."
                    : win.cur.id === "gen" ? "Keeps your Accent and builds the other colours around it."
                    : win.cur.id === "random" ? "A fresh palette from a random accent. Press Enter again for another."
                    : win.cur.id === "reset" ? "Throws away your edits and reloads the theme you started from."
                    : "Writes the theme file, selects it, and closes. (Ctrl+S works from anywhere.)"
            }
        }

        Text {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 14 }
            horizontalAlignment: Text.AlignHCenter
            text: "↑↓ select   ←→ hue   shift sat   ctrl light   ⏎ edit / run   ctrl+s save   esc cancel"
            color: Theme.dim
            font { family: Theme.font; pixelSize: 10 }
        }
    }
}
