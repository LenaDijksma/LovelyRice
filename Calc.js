.pragma library
// Small safe calculator (no eval). + - * / ^ % ( ), × ÷, decimal comma or dot,
// constants pi e, functions sqrt cbrt sin cos tan asin acos atan log ln exp abs round floor ceil.
function evaluate(src) {
    var s = String(src).toLowerCase().replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, ".")
    var pos = 0
    function peek() { while (pos < s.length && s[pos] === " ") pos++; return pos < s.length ? s[pos] : "" }
    function fail() { throw new Error("calc") }
    var fns = {
        sqrt: Math.sqrt, cbrt: Math.cbrt, sin: Math.sin, cos: Math.cos, tan: Math.tan,
        asin: Math.asin, acos: Math.acos, atan: Math.atan, log: Math.log10, ln: Math.log,
        exp: Math.exp, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil
    }
    function atom() {
        var c = peek()
        if (c === "(") { pos++; var v = expr(); if (peek() !== ")") fail(); pos++; return v }
        var m = /^(\d+\.?\d*|\.\d+)/.exec(s.slice(pos))
        if (m && c !== "") { pos += m[0].length; return parseFloat(m[0]) }
        m = /^[a-z]+/.exec(s.slice(pos))
        if (!m) fail()
        pos += m[0].length
        var id = m[0]
        if (id === "pi") return Math.PI
        if (id === "e") return Math.E
        if (fns[id] && peek() === "(") { pos++; var a = expr(); if (peek() !== ")") fail(); pos++; return fns[id](a) }
        fail()
    }
    function power() {
        var b = atom()
        if (peek() === "^") { pos++; return Math.pow(b, unary()) }
        return b
    }
    function unary() {
        var c = peek()
        if (c === "-") { pos++; return -unary() }
        if (c === "+") { pos++; return unary() }
        return power()
    }
    function term() {
        var v = unary()
        for (;;) {
            var c = peek()
            if (c === "*") { pos++; v *= unary() }
            else if (c === "/") { pos++; v /= unary() }
            else if (c === "%") { pos++; v %= unary() }
            else return v
        }
    }
    function expr() {
        var v = term()
        for (;;) {
            var c = peek()
            if (c === "+") { pos++; v += term() }
            else if (c === "-") { pos++; v -= term() }
            else return v
        }
    }
    try {
        var r = expr()
        if (peek() !== "") return null
        return isFinite(r) ? r : null
    } catch (e) { return null }
}
