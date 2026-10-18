.pragma library
// Colour helpers for the scheme maker: hex <-> HSL, palette generation.
function clamp(v, a, b) { return Math.max(a, Math.min(b, v)) }

function normalizeHex(s) {
    s = String(s).trim()
    if (s[0] === "#") s = s.slice(1)
    if (/^[0-9a-fA-F]{3}$/.test(s)) s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2]
    if (!/^[0-9a-fA-F]{6}$/.test(s)) return ""
    return "#" + s.toLowerCase()
}
function hexToHsl(hex) {
    var h6 = normalizeHex(hex)
    if (h6 === "") return [0, 0, 0]
    var r = parseInt(h6.slice(1, 3), 16) / 255, g = parseInt(h6.slice(3, 5), 16) / 255, b = parseInt(h6.slice(5, 7), 16) / 255
    var mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, h = 0, s = 0
    if (mx !== mn) {
        var d = mx - mn
        s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
        if (mx === r) h = (g - b) / d + (g < b ? 6 : 0)
        else if (mx === g) h = (b - r) / d + 2
        else h = (r - g) / d + 4
        h *= 60
    }
    return [h, s * 100, l * 100]
}
function hslToHex(h, s, l) {
    h = ((h % 360) + 360) % 360; s = clamp(s, 0, 100) / 100; l = clamp(l, 0, 100) / 100
    var c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs((h / 60) % 2 - 1)), m = l - c / 2, r = 0, g = 0, b = 0
    if (h < 60) { r = c; g = x } else if (h < 120) { r = x; g = c } else if (h < 180) { g = c; b = x }
    else if (h < 240) { g = x; b = c } else if (h < 300) { r = x; b = c } else { r = c; b = x }
    function t(v) { var n = Math.round((v + m) * 255).toString(16); return n.length < 2 ? "0" + n : n }
    return "#" + t(r) + t(g) + t(b)
}
// Full palette from one accent colour.
function generate(accent, light) {
    var a = hexToHsl(accent), h = a[0], s = a[1], l = a[2]
    var tint = Math.min(s, 28), h2 = (h + 45) % 360
    if (!light) return {
        bg: hslToHex(h, tint * 0.55, 6), surface: hslToHex(h, tint * 0.6, 11),
        fg: hslToHex(h, 20, 90), dim: hslToHex(h, 10, 48), accent: normalizeHex(accent),
        accent2: hslToHex(h2, clamp(s, 45, 90), clamp(l, 55, 70)), warn: hslToHex(38, 90, 62)
    }
    return {
        bg: hslToHex(h, tint * 0.7, 95), surface: hslToHex(h, tint * 0.7, 89),
        fg: hslToHex(h, 25, 14), dim: hslToHex(h, 10, 48), accent: normalizeHex(accent),
        accent2: hslToHex(h2, clamp(s, 45, 85), clamp(l, 35, 50)), warn: hslToHex(30, 90, 40)
    }
}
function randomAccent(light) {
    return hslToHex(Math.random() * 360, 60 + Math.random() * 25, light ? 40 + Math.random() * 10 : 62 + Math.random() * 8)
}

// Palette from a wallpaper: `px` is a list of "#rrggbb" pixels (a small downscaled copy of the image).
// Picks the most vivid hue family as the accent and a second, different hue as accent2; the rest comes from generate().
function fromPixels(px, light) {
    var b = [], i
    for (i = 0; i < 12; i++) b.push({ w: 0, h: 0, s: 0, l: 0 })
    for (i = 0; i < px.length; i++) {
        var v = hexToHsl(px[i]), h = v[0], s = v[1], l = v[2]
        if (s < 25 || l < 15 || l > 88) continue
        var w = (s / 100) * (1 - Math.abs(l - 50) / 50)
        var k = b[Math.min(11, Math.floor(h / 30))]
        k.w += w; k.h += w * h; k.s += w * s; k.l += w * l
    }
    var ranked = b.filter(function (k) { return k.w > 0 }).sort(function (x, y) { return y.w - x.w })
    if (ranked.length === 0) return generate(hslToHex(215, 55, light ? 45 : 64), light)
    function pick(k, lo, hi) { return hslToHex(k.h / k.w, clamp(k.s / k.w, 55, 90), clamp(k.l / k.w, lo, hi)) }
    var top = ranked[0]
    var pal = generate(pick(top, light ? 38 : 58, light ? 50 : 70), light)
    for (i = 1; i < ranked.length; i++) {
        var d = Math.abs(ranked[i].h / ranked[i].w - top.h / top.w)
        d = Math.min(d, 360 - d)
        if (ranked[i].w > top.w * 0.25 && d >= 40) { pal.accent2 = pick(ranked[i], light ? 35 : 55, light ? 50 : 70); break }
    }
    return pal
}

// 16 terminal colors for a theme `p` = { bg, surface, fg, dim, accent, accent2, warn } (all "#rrggbb").
// The standard hues (red 0, yellow 48, green 125, cyan 180, blue 215, magenta 300) take the saturation and lightness
// of the accent, so they sit well on the theme's background. A theme color that is within 20 degrees of one of those
// hues replaces it (gruvbox's red, tokyo-night's blue, ...); the accent wins over accent2 and warn.
// Returns { light: bool, c: [16 hex strings] } in ANSI order (0-7 normal, 8-15 bright).
function ansi(p) {
    var light = hexToHsl(p.bg)[2] > 55
    var a = hexToHsl(p.accent)
    var s = clamp(a[1], 40, 72)
    var l = light ? clamp(a[2], 30, 44) : clamp(a[2], 60, 72)
    var slots = { 1: 0, 2: 125, 3: 48, 4: 215, 5: 300, 6: 180 }     // ANSI index -> hue
    var col = {}
    var k
    for (k in slots) col[k] = hslToHex(slots[k], s, l)
    function claim(hex) {
        var h6 = normalizeHex(hex)
        if (h6 === "") return
        var hsl = hexToHsl(h6), best = -1, bd = 21
        if (hsl[1] < 15) return                                      // greys don't name a hue
        for (var i in slots) {
            var d = Math.abs(hsl[0] - slots[i]); d = Math.min(d, 360 - d)
            if (d < bd) { bd = d; best = i }
        }
        if (best >= 0) col[best] = h6
    }
    claim(p.accent2); claim(p.warn); claim(p.accent)
    var out = []
    var shift = light ? -7 : 8
    function bright(hex) { var h = hexToHsl(hex); return hslToHex(h[0], clamp(h[1] + 5, 0, 100), clamp(h[2] + shift, 0, 100)) }
    var fgh = hexToHsl(p.fg)
    out[0] = light ? normalizeHex(p.fg) : normalizeHex(p.surface)
    out[7] = light ? normalizeHex(p.surface) : hslToHex(fgh[0], fgh[1], fgh[2] * 0.86)
    out[8] = normalizeHex(p.dim)
    out[15] = light ? normalizeHex(p.bg) : normalizeHex(p.fg)
    for (k = 1; k <= 6; k++) { out[k] = col[k]; out[k + 8] = bright(col[k]) }
    return { light: light, c: out }
}
