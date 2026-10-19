.pragma library

// Fuzzy matching for the palette. score(q, text) is -1 when `q` is not a subsequence of `text`, otherwise bigger = better:
//   a plain substring beats a scattered match (prefix > word start > anywhere), scattered matches earn points for
//   consecutive letters and for letters at the start of a word, and shorter texts win ties ("fire" -> Firefox, not
//   "Fire Emblem Fan Edition"). Both strings are lowercased here, so callers can pass them as they are.
function isStart(s, i) {
    if (i === 0) return true
    const p = s.charAt(i - 1)
    return p === " " || p === "-" || p === "_" || p === "." || p === "/" || p === ":" || p === "("
}

function score(q, text) {
    if (q === "") return 1
    const s = String(text).toLowerCase()
    q = q.toLowerCase()
    const at = s.indexOf(q)
    if (at >= 0) return 1000 + (at === 0 ? 300 : (isStart(s, at) ? 150 : 0)) - Math.min(s.length, 100) * 0.5
    if (q.length > s.length) return -1
    let si = 0, last = -2, run = 0, total = 0
    for (let qi = 0; qi < q.length; qi++) {
        const c = q.charAt(qi)
        while (si < s.length && s.charAt(si) !== c) si++
        if (si >= s.length) return -1
        let pts = 10
        if (si === last + 1) { run++; pts += 8 * Math.min(run, 4) } else run = 0
        if (isStart(s, si)) pts += 15
        total += pts
        last = si
        si++
    }
    return Math.min(total, 900) - Math.min(s.length, 100) * 0.3
}

// Name matches fuzzily; the extra text (description, keywords) only counts as a plain substring, so a long
// description doesn't let random letters match.
function match(q, name, extra) {
    if (q === "") return 1
    const n = score(q, name)
    if (n >= 0) return n
    if (extra && String(extra).toLowerCase().indexOf(q.toLowerCase()) >= 0) return 200
    return -1
}
