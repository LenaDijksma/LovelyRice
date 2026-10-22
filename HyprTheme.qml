pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Hyprland integration: window borders, rounding, gaps, blur, shadow and opacity follow the theme and the bar (/settings -> Hyprland).
// Off until you turn it on. While it is on, LovelyRice applies these values to the running compositor:
//   - when it starts, when the theme / wallpaper / a Hyprland setting changes, and after Hyprland reloads its config
//   - with `hyprctl eval "hl.config({...})"` (Hyprland 0.55+ Lua config), or `hyprctl keyword` on an older .conf config
// Nothing is written to your hyprland.lua. Turning it off runs `hyprctl reload`, which puts your own values back.
// The answer Hyprland gave is in ~/.local/state/lovelyrice/generated/last-hypr.log (`lovelyrice hypr log`).
Singleton {
    id: root

    readonly property string script: Quickshell.shellPath("scripts/hypr-apply.sh")

    function hex(c) {
        function t(v) { const n = Math.round(v * 255).toString(16); return n.length < 2 ? "0" + n : n }
        return t(c.r) + t(c.g) + t(c.b)
    }
    function rgba(c, a) {
        const n = Math.round(Math.max(0, Math.min(1, a)) * 255).toString(16)
        return "rgba(" + hex(c) + (n.length < 2 ? "0" + n : n) + ")"
    }

    // every value that goes to Hyprland, as sections of hl.config
    readonly property var plan: {
        const S = Settings
        const general = {}, decoration = {}
        if (S.hyprBorders) {
            const act = S.hyprBorderStyle === "solid" ? [rgba(Theme.accent, 0.95)] : [rgba(Theme.accent, 0.95), rgba(Theme.accent2, 0.95)]
            general.act = act
            general.inact = [rgba(Theme.dim, 0.45)]
        }
        if (S.hyprShape) {
            general.border_size = S.hyprBorderSize
            general.gaps_out = S.hyprGapsFollow ? S.gap : S.hyprGapsOut
            general.gaps_in = S.hyprGapsFollow ? Math.round(S.gap / 2) : S.hyprGapsIn
            decoration.rounding = S.hyprRoundFollow ? S.barRadius : S.hyprRounding
        }
        decoration.blur = S.hyprBlur ? { enabled: true, size: S.hyprBlurSize, passes: S.hyprBlurPasses } : null
        if (S.hyprShadow) decoration.shadow = { enabled: true, range: S.hyprShadowRange,
                                                color: S.hyprShadowGlow ? rgba(Theme.accent, 0.55) : rgba(Qt.rgba(0, 0, 0, 1), 0.6) }
        if (S.hyprOpacity) { decoration.active_opacity = S.hyprActiveOpacity / 100; decoration.inactive_opacity = S.hyprInactiveOpacity / 100 }
        return { general: general, decoration: decoration }
    }

    // the same plan as a Lua snippet and as `hyprctl keyword` lines
    function lua(p) {
        const g = p.general, d = p.decoration
        const gp = []
        if (g.border_size !== undefined) gp.push("border_size = " + g.border_size)
        if (g.gaps_in !== undefined) gp.push("gaps_in = " + g.gaps_in)
        if (g.gaps_out !== undefined) gp.push("gaps_out = " + g.gaps_out)
        if (g.act) gp.push("col = { active_border = { colors = { " + g.act.map(c => '"' + c + '"').join(", ") + " }, angle = 45 }, "
                           + "inactive_border = { colors = { " + g.inact.map(c => '"' + c + '"').join(", ") + " } } }")
        const dp = []
        if (d.rounding !== undefined) dp.push("rounding = " + d.rounding)
        if (d.active_opacity !== undefined) dp.push("active_opacity = " + d.active_opacity + ", inactive_opacity = " + d.inactive_opacity)
        dp.push("blur = { enabled = " + (d.blur ? "true, size = " + d.blur.size + ", passes = " + d.blur.passes : "false") + " }")
        if (d.shadow) dp.push('shadow = { enabled = true, range = ' + d.shadow.range + ', color = "' + d.shadow.color + '" }')
        const parts = []
        if (gp.length) parts.push("general = { " + gp.join(", ") + " }")
        parts.push("decoration = { " + dp.join(", ") + " }")
        return "hl.config({ " + parts.join(", ") + " })"
    }
    function keywords(p) {
        const g = p.general, d = p.decoration, out = []
        if (g.border_size !== undefined) out.push("keyword general:border_size " + g.border_size)
        if (g.gaps_in !== undefined) out.push("keyword general:gaps_in " + g.gaps_in)
        if (g.gaps_out !== undefined) out.push("keyword general:gaps_out " + g.gaps_out)
        if (g.act) {
            out.push("keyword general:col.active_border " + g.act.join(" ") + (g.act.length > 1 ? " 45deg" : ""))
            out.push("keyword general:col.inactive_border " + g.inact.join(" "))
        }
        if (d.rounding !== undefined) out.push("keyword decoration:rounding " + d.rounding)
        if (d.active_opacity !== undefined) { out.push("keyword decoration:active_opacity " + d.active_opacity); out.push("keyword decoration:inactive_opacity " + d.inactive_opacity) }
        out.push("keyword decoration:blur:enabled " + (d.blur ? 1 : 0))
        if (d.blur) { out.push("keyword decoration:blur:size " + d.blur.size); out.push("keyword decoration:blur:passes " + d.blur.passes) }
        if (d.shadow) { out.push("keyword decoration:shadow:enabled 1"); out.push("keyword decoration:shadow:range " + d.shadow.range); out.push("keyword decoration:shadow:color " + d.shadow.color) }
        return out.join(" ; ")
    }

    function start() { bootTimer.start() }
    function apply() { if (Settings.hyprSync) { settle.restart() } }
    function applyNow() { if (Settings.hyprSync) run() }
    function release() { Quickshell.execDetached(["hyprctl", "reload"]) }     // back to what your own config says

    function run() {
        if (proc.running) { settle.restart(); return }
        proc.command = ["sh", root.script, root.lua(root.plan), root.keywords(root.plan)]
        proc.running = true
    }

    // let a color fade or a slider drag finish before talking to Hyprland
    Timer { id: settle; interval: 700; onTriggered: root.run() }
    Timer { id: bootTimer; interval: 3500; onTriggered: root.apply() }
    onPlanChanged: apply()
    Connections {
        target: Settings
        function onHyprSyncChanged() { if (Settings.hyprSync) root.apply(); else if (Settings.loaded) root.release() }
    }
    // Hyprland dropped our values when it reloaded its config
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") root.apply() }
    }
    Process { id: proc }
}
