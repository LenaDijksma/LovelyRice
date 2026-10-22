#!/bin/sh
# Applies LovelyRice's Hyprland settings to the running compositor. Run by HyprTheme.qml:
#   hypr-apply.sh '<lua snippet>' '<hyprctl --batch keyword lines>'
# Hyprland 0.55+ with a Lua config takes the Lua snippet (hyprctl eval); an older .conf config takes the keyword lines.
# What Hyprland answered goes to ~/.local/state/lovelyrice/generated/last-hypr.log.
out="${HOME}/.local/state/lovelyrice/generated"
mkdir -p "$out" 2>/dev/null
log="$out/last-hypr.log"
command -v hyprctl >/dev/null 2>&1 || { echo "hyprctl not found" > "$log"; exit 1; }
{
    echo "# $(date '+%F %T')"
    echo "lua:  $1"
    r=$(hyprctl eval "$1" 2>&1)
    echo "eval: $r"
    case "$r" in
        ok|"") echo "result: applied with hyprctl eval"; exit 0 ;;
    esac
    echo "keywords: $2"
    r2=$(hyprctl --batch "$2" 2>&1)
    echo "batch: $r2"
    case "$r2" in
        *error*|*Error*|*invalid*|*unknown*) echo "result: Hyprland refused both forms (see above)"; exit 1 ;;
        *) echo "result: applied with hyprctl keyword" ;;
    esac
} > "$log" 2>&1
