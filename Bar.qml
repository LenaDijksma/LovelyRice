pragma Singleton
import QtQuick
import Quickshell

// Where the utility bar(s) are, and the maths the popouts need to fly out of them.
// Popouts are PanelWindows placed with margins; their card starts hidden behind the bar edge and slides out.
//
// There can be two bars (Settings.barSplit). `position` / `horizontal` / `inset` describe bar 1; the functions that take
// an optional `p` (a position: left | right | top | bottom) work for whichever bar a popout belongs to, so the volume popout
// can leave the side bar while the media popout leaves the top bar. `posOf(module)` says which bar a module is on.
Singleton {
    id: root

    readonly property string position: Settings.barPosition      // bar 1: left | right | top | bottom
    readonly property bool horizontal: Theme.horizontal           // bar 1 is on the top or bottom
    readonly property bool vertical: !horizontal                  // bar 1 is on the left or right
    readonly property bool hidden: Settings.barVisibility === "hidden"
    // screen edge -> first free pixel, for a bar that is there (a hidden bar leaves just its gap)
    readonly property int inset: hidden ? Theme.gap : Theme.gap * 2 + Theme.barThickness
    readonly property int fly: 14                                 // how far the card ends up from the bar edge

    function _p(p) { return p || position }
    function isHorizontal(p) { p = _p(p); return p === "top" || p === "bottom" }

    // is there a bar on this screen edge? (bar 2 counts when the split is on and it has modules)
    function occupies(side) {
        if (hidden) return false
        return Settings.barPosition === side || (Settings.barExists(2) && Settings.bar2Position === side)
    }
    // how far in from `side` the bars reach (0 when none is there): panels and toasts keep clear of this
    function insetOn(side) { return occupies(side) ? inset : 0 }

    // the position of the bar a module lives on
    function posOf(moduleId) {
        if (Settings.barExists(2) && Settings.bar2Modules.indexOf(moduleId) >= 0) return Settings.bar2Position
        return Settings.barPosition
    }

    // shadow pointing away from the bar edge
    function shadowXFor(p) { p = _p(p); return p === "left" ? 4 : (p === "right" ? -4 : 0) }
    function shadowYFor(p) { p = _p(p); return p === "bottom" ? -6 : 6 }
    readonly property real shadowX: shadowXFor(position)
    readonly property real shadowY: shadowYFor(position)

    // size of a popout window around a card: a little room to fly along the bar's normal, shadow padding all round
    function winWidth(cardW, p)  { return isHorizontal(p) ? cardW + 2 * Theme.shadowPad : cardW + 24 + Theme.shadowPad }
    function winHeight(cardH, p) { return isHorizontal(p) ? cardH + 24 + Theme.shadowPad : cardH + 2 * Theme.shadowPad }

    // Window margins for a popout anchored top + left. `want` is where the window would like its near edge to be
    // along the bar (the other axis is fixed by the bar itself); it is kept on screen.
    function originX(screenW, winW, want, p) {
        p = _p(p)
        if (p === "left")  return inset
        if (p === "right") return Math.max(0, screenW - inset - winW)
        return Math.max(0, Math.min(screenW - winW, want))
    }
    function originY(screenH, winH, want, p) {
        p = _p(p)
        if (p === "top")    return inset
        if (p === "bottom") return Math.max(0, screenH - inset - winH)
        return Math.max(0, Math.min(screenH - winH, want))
    }

    // Card position inside its window while it flies (progress 0 = hidden behind the bar, 1 = out).
    // Across the bar the card sits in the middle of its window.
    function flyX(cardW, parentW, progress, p) {
        p = _p(p)
        if (p === "left")  return -cardW + (cardW + fly) * progress
        if (p === "right") return parentW - (cardW + fly) * progress
        return (parentW - cardW) / 2
    }
    function flyY(cardH, parentH, progress, p) {
        p = _p(p)
        if (p === "top")    return -cardH + (cardH + fly) * progress
        if (p === "bottom") return parentH - (cardH + fly) * progress
        return (parentH - cardH) / 2
    }

    // ---- what a bar module asks its bar ----
    // Modules sit inside a bar's layout. The layout carries `barHorizontal` (which way its bar runs) and `glassBackdrop`
    // (the wallpaper copy glass pills sample); a module finds them by walking up its parents. The walk happens inside a
    // binding, so it re-runs by itself if the module is moved to the other bar.
    function horizontalFor(item) {
        let p = item
        while (p) {
            if (p.barHorizontal !== undefined) return p.barHorizontal
            p = p.parent
        }
        return Theme.horizontal
    }
    function backdropFor(item) {
        let p = item
        while (p) {
            if (p.glassBackdrop !== undefined) return p.glassBackdrop
            p = p.parent
        }
        return null
    }
}
