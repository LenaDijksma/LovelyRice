#!/bin/sh
# lovelyrice setup [foot|gtk|greet|all] [--remove]
#
# Hooks the generated theme files (see scripts/theme-sync.sh) into your own configs. Nothing is edited until you run
# this, every edit is one clearly marked block, and --remove takes the block out again. Safe to run twice.
#   foot   adds `include=` to foot.ini and creates ~/.config/foot/lovelyrice-colors.ini
#   gtk    adds an @import to ~/.config/gtk-3.0/gtk.css and gtk-4.0/gtk.css and creates lovelyrice.css next to each
#   greet  adds a small block to .bashrc / .zshrc / fish conf.d: theme colors + the fastfetch cat in new foot windows

set -u
cfg="${XDG_CONFIG_HOME:-$HOME/.config}"
gen="$HOME/.local/state/lovelyrice/generated"
remove=0; what=""
for a in "$@"; do
    case "$a" in
        --remove|--undo|-r) remove=1 ;;
        foot|gtk|greet|all) what="$what $a" ;;
        -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "lovelyrice setup: unknown argument '$a' (foot, gtk, greet, all, --remove)" >&2; exit 2 ;;
    esac
done
[ -n "$what" ] || what=" all"
case "$what" in *all*) what=" foot gtk greet" ;; esac

# block <file> <begin> <end> -> remove the marked block from the file if present
unblock() {
    [ -f "$1" ] || return 0
    grep -qF "$2" "$1" || return 0
    tmp="$1.lr.$$"
    # also drops the one blank line that append() puts in front of the block
    awk -v b="$2" -v e="$3" '
        { if (index($0, b)) { skip = 1; if (n > 0 && o[n] == "") n-- }
          if (!skip) o[++n] = $0
          if (index($0, e)) skip = 0 }
        END { for (i = 1; i <= n; i++) print o[i] }' "$1" > "$tmp" && cat "$tmp" > "$1"
    rm -f "$tmp"
}
# prepend <file> <begin> <end> <body>: put the block at the top (creating the file); replaces an older copy of the block
prepend() {
    mkdir -p "$(dirname "$1")"
    unblock "$1" "$2" "$3"
    tmp="$1.lr.$$"
    { printf '%s\n%s\n%s\n' "$2" "$4" "$3"; [ -f "$1" ] && cat "$1"; } > "$tmp" && cat "$tmp" > "$1"
    rm -f "$tmp"
}
# append <file> <begin> <end> <body>: same, at the end
append() {
    mkdir -p "$(dirname "$1")"
    unblock "$1" "$2" "$3"
    printf '\n%s\n%s\n%s\n' "$2" "$4" "$3" >> "$1"
}

do_foot() {
    ini="$cfg/foot/foot.ini"; inc="$cfg/foot/lovelyrice-colors.ini"
    b='# >>> lovelyrice >>>'; e='# <<< lovelyrice <<<'
    if [ "$remove" = 1 ]; then
        unblock "$ini" "$b" "$e"; rm -f "$inc"
        echo "foot: removed the include from $ini"; return
    fi
    mkdir -p "$cfg/foot"
    if [ -f "$gen/foot-colors.ini" ]; then cp "$gen/foot-colors.ini" "$inc"; else printf '[colors-dark]\n' > "$inc"; fi
    prepend "$ini" "$b" "$e" "include=$inc"
    echo "foot: $ini now includes $inc"
    if grep -Eq '^\[colors(-dark|-light)?\]' "$ini" 2>/dev/null; then
        echo "foot: note - your foot.ini has its own [colors] section, which wins for NEW windows. Delete it to let LovelyRice"
        echo "      pick the colors (running windows and the greeting still follow the theme either way)."
    fi
}

do_gtk() {
    b='/* >>> lovelyrice >>> */'; e='/* <<< lovelyrice <<< */'
    for v in 3.0 4.0; do
        css="$cfg/gtk-$v/gtk.css"; mine="$cfg/gtk-$v/lovelyrice.css"
        if [ "$remove" = 1 ]; then
            unblock "$css" "$b" "$e"; rm -f "$mine"
            [ -f "$css" ] && [ ! -s "$css" ] && rm -f "$css"
            rmdir "$cfg/gtk-$v" 2>/dev/null
            echo "gtk-$v: removed the import"
            continue
        fi
        mkdir -p "$cfg/gtk-$v"
        if [ -f "$gen/gtk.css" ]; then cp "$gen/gtk.css" "$mine"; else echo "/* LovelyRice: waiting for the first theme sync */" > "$mine"; fi
        prepend "$css" "$b" "$e" '@import url("lovelyrice.css");'
        echo "gtk-$v: $css imports lovelyrice.css"
    done
    [ "$remove" = 1 ] && return
    if command -v gsettings >/dev/null 2>&1; then
        t=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
        case "$t" in
            Adwaita*|adw-gtk3*|"") ;;
            *) echo "gtk: your GTK theme is '$t'. The colors apply to libadwaita (GTK 4) apps and to the Adwaita / adw-gtk3 themes;"
               echo "     for GTK 3 apps run:  gsettings set org.gnome.desktop.interface gtk-theme Adwaita   (or adw-gtk3-dark)" ;;
        esac
    fi
}

do_greet() {
    b='# >>> lovelyrice >>>'; e='# <<< lovelyrice <<<'
    body='# LovelyRice: theme colors and the fastfetch cat in new foot windows (lovelyrice setup greet --remove to drop this)
if [ -t 1 ] && [ -z "${TMUX:-}" ] && [ "${TERM%%-*}" = foot ] && [ "${LR_GREET_TTY:-}" != "$(tty 2>/dev/null)" ]; then
    export LR_GREET_TTY="$(tty 2>/dev/null)"
    command -v lovelyrice >/dev/null 2>&1 && lovelyrice greet
fi'
    fishfile="$cfg/fish/conf.d/lovelyrice.fish"
    fishbody='# LovelyRice: theme colors and the fastfetch cat in new foot windows (lovelyrice setup greet --remove to drop this)
if status is-interactive; and test -z "$TMUX"; and string match -q "foot*" -- $TERM
    set -l lr_tty (tty 2>/dev/null)
    if test "$LR_GREET_TTY" != "$lr_tty"
        set -gx LR_GREET_TTY $lr_tty
        command -q lovelyrice; and lovelyrice greet
    end
end'
    done_any=0
    for rc in "$HOME/.bashrc" "${ZDOTDIR:-$HOME}/.zshrc"; do
        [ -f "$rc" ] || continue
        if [ "$remove" = 1 ]; then unblock "$rc" "$b" "$e"; echo "greet: removed from $rc"
        else append "$rc" "$b" "$e" "$body"; echo "greet: added to $rc"; done_any=1; fi
    done
    if [ "$remove" = 1 ]; then
        [ -f "$fishfile" ] && { rm -f "$fishfile"; rmdir "$cfg/fish/conf.d" 2>/dev/null; echo "greet: removed $fishfile"; }
    elif [ -d "$cfg/fish" ] || command -v fish >/dev/null 2>&1; then
        mkdir -p "$cfg/fish/conf.d"; printf '%s\n' "$fishbody" > "$fishfile"; echo "greet: added $fishfile"; done_any=1
    fi
    if [ "$remove" != 1 ]; then
        [ "$done_any" = 1 ] || echo "greet: found no .bashrc, .zshrc or fish config to edit; add the lines from 'lovelyrice help' yourself."
        command -v fastfetch >/dev/null 2>&1 || echo "greet: fastfetch is not installed (sudo pacman -S fastfetch); the colors still apply."
        echo "greet: open a new foot window to see it. LR_NO_FETCH=1 keeps the colors but skips the fastfetch."
    fi
}

for w in $what; do
    case "$w" in foot) do_foot ;; gtk) do_gtk ;; greet) do_greet ;; esac
done
if [ "$remove" != 1 ]; then
    echo
    echo "Done. Apply the current theme now with:  lovelyrice sync"
    [ -f "$gen/gtk.css" ] || echo "(the generated files appear after LovelyRice has started once)"
fi
exit 0
