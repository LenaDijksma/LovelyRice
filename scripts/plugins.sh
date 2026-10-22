#!/bin/sh
# LovelyRice plugin manager: the filesystem side of the plugin system.
# Used by `lovelyrice plugin ...` and by the shell itself (Plugins.qml runs `plugins.sh scan`).
#
#   plugins.sh scan                machine-readable: one line per plugin, ends with "#ok"
#                                  name<TAB>allowed<TAB>enabled<TAB>trust<TAB>sig<TAB>manifest (one line)
#   plugins.sh list                human-readable table
#   plugins.sh info <name>         manifest, folder, revision, trust state
#   plugins.sh path                print the plugins folder
#   plugins.sh install <git-url>   clone into the plugins folder. Loads NOTHING.
#   plugins.sh new <name>          scaffold a plugin from plugins-examples/hello
#   plugins.sh allow <name>        trust it (pins the git revision) and turn it on
#   plugins.sh enable|disable <name>
#   plugins.sh revoke <name>       take the trust back (also turns it off)
#   plugins.sh update <name>       git pull; if the code changed, the trust is void until `allow` again
#   plugins.sh remove <name>       delete the plugin and its stored data
#
# A plugin is arbitrary QML running with your full permissions. Nothing here is a sandbox.
#
# Files:   ~/.config/lovelyrice/plugins/<name>/{plugin.json,Main.qml,...}
# State:   ~/.local/state/lovelyrice/plugins.state    lines "allow <name> <rev>" and "enable <name>"
#          (<rev> is the git commit that was allowed, or "-" for a folder that is not a git checkout)

set -u

dir="${LR_PLUGIN_DIR:-$HOME/.config/lovelyrice/plugins}"
stdir="${LR_STATE_DIR:-$HOME/.local/state/lovelyrice}"
state="$stdir/plugins.state"
here=$(cd "$(dirname "$0")" && pwd)

die()  { echo "lovelyrice plugin: $*" >&2; exit 1; }
good() { case "$1" in ''|-*|*[!a-z0-9_-]*) return 1 ;; esac; [ "${#1}" -le 40 ]; }   # a safe folder / plugin name
need_name() {
    [ $# -ge 1 ] || die "missing plugin name"
    good "$1" || die "bad plugin name '$1' (lowercase letters, digits, - and _ only)"
}
installed() { [ -f "$dir/$1/plugin.json" ]; }

# the git commit of a plugin folder, or "-"
rev_of() {
    r=$(git -C "$dir/$1" rev-parse HEAD 2>/dev/null) && [ -n "$r" ] && { echo "$r"; return; }
    echo "-"
}
one_line() { head -c 16384 "$1" 2>/dev/null | tr '\n\t\r' '   '; }
json_str() {   # json_str <key> from a one-line manifest on stdin: the first string value of that key
    sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}
state_has() { [ -f "$state" ] && grep -q "^$1 $2\( \|\$\)" "$state"; }
state_rev() { [ -f "$state" ] && sed -n "s/^allow $1 //p" "$state" | head -n 1; }
state_drop() {   # state_drop <name> [allow|enable]: forget lines about a plugin
    [ -f "$state" ] || return 0
    case "${2:-}" in
        allow)  grep -v "^allow $1 " "$state" > "$state.tmp" ;;
        enable) grep -v "^enable $1\$" "$state" > "$state.tmp" ;;
        *)      grep -v -e "^allow $1 " -e "^enable $1\$" "$state" > "$state.tmp" ;;
    esac
    mv "$state.tmp" "$state"
}
state_add() { mkdir -p "$stdir" && echo "$1" >> "$state"; }

# ok = allowed and the code is the code that was allowed; changed = allowed once, the code moved on; none = never allowed
trust_of() {
    stored=$(state_rev "$1") || stored=""
    [ -n "$stored" ] || { echo none; return; }
    [ "$stored" = "$(rev_of "$1")" ] && echo ok || echo changed
}
sig_of() {   # changes whenever a file in the plugin changes (used for hot reload)
    find "$dir/$1" -type f ! -path '*/.git/*' -printf '%T@ %s %p\n' 2>/dev/null | sort | cksum | tr ' ' '-'
}

cmd_scan() {
    for d in "$dir"/*/; do
        [ -f "${d}plugin.json" ] || continue
        n=$(basename "$d")
        good "$n" || continue
        a=0; e=0
        state_has allow "$n" && a=1
        state_has enable "$n" && e=1
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$n" "$a" "$e" "$(trust_of "$n")" "$(sig_of "$n")" "$(one_line "${d}plugin.json")"
    done
    echo "#ok"
}

cmd_list() {
    cmd_scan | while IFS="$(printf '\t')" read -r n a e t s j; do
        [ "$n" = "#ok" ] && continue
        v=$(printf %s "$j" | json_str version)
        if   [ "$t" = changed ]; then st="CHANGED since you allowed it: review it, then 'allow' again"
        elif [ "$a" = 1 ] && [ "$e" = 1 ]; then st="on"
        elif [ "$a" = 1 ]; then st="allowed, off"
        else st="not allowed (nothing loads until you run: lovelyrice plugin allow $n)"
        fi
        printf '%-20s %-8s %s\n' "$n" "${v:--}" "$st"
    done
    [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ] || {
        echo "No plugins in $dir"
        echo "Create one:  lovelyrice plugin new <name>      Install one:  lovelyrice plugin install <git-url>"
    }
}

cmd_info() {
    need_name "$@"; installed "$1" || die "no plugin '$1' in $dir"
    j=$(one_line "$dir/$1/plugin.json")
    echo "name:     $1"
    echo "version:  $(printf %s "$j" | json_str version)"
    echo "folder:   $dir/$1"
    echo "revision: $(rev_of "$1")"
    url=$(git -C "$dir/$1" remote get-url origin 2>/dev/null) && echo "source:   $url"
    echo "trust:    $(trust_of "$1")   (none = never allowed, ok = allowed, changed = code moved since allowed)"
    state_has enable "$1" && echo "enabled:  yes" || echo "enabled:  no"
    echo "manifest: $j"
}

cmd_install() {
    [ $# -ge 1 ] || die "usage: lovelyrice plugin install <git-url>"
    url="$1"
    case "$url" in -*) die "that does not look like a git URL: $url" ;; esac
    command -v git >/dev/null 2>&1 || die "git is not installed"
    mkdir -p "$dir"
    tmp="$dir/.install.$$"
    rm -rf "$tmp"
    echo "Cloning $url ..."
    # only plain transports: git's ext:: transport would run commands
    GIT_ALLOW_PROTOCOL=https:ssh:git:file GIT_TERMINAL_PROMPT=0 git clone --quiet --depth 1 -- "$url" "$tmp" \
        || { rm -rf "$tmp"; die "git clone failed"; }
    [ -f "$tmp/plugin.json" ] || { rm -rf "$tmp"; die "no plugin.json in that repository, so it is not a LovelyRice plugin"; }
    j=$(one_line "$tmp/plugin.json")
    name=$(printf %s "$j" | json_str name)
    good "$name" || { rm -rf "$tmp"; die "plugin.json has no usable \"name\" (lowercase letters, digits, - and _)"; }
    [ ! -e "$dir/$name" ] || { rm -rf "$tmp"; die "'$name' is already installed ($dir/$name). Remove it first."; }
    mv "$tmp" "$dir/$name"

    echo
    echo "Installed '$name' $(printf %s "$j" | json_str version)"
    echo "  from:     $url"
    echo "  commit:   $(rev_of "$name")"
    echo "  folder:   $dir/$name"
    echo
    echo "A plugin is arbitrary QML that runs inside your desktop shell with your full permissions:"
    echo "it can read your files, run programs and use the network. The \"provides\" list in plugin.json"
    echo "describes what it is meant to add; it does not limit what it can do."
    echo
    echo "NOTHING HAS BEEN LOADED. Read the code first:   $dir/$name/Main.qml"
    echo "If you trust it:                                lovelyrice plugin allow $name"
}

cmd_new() {
    need_name "$@"
    n="$1"
    [ ! -e "$dir/$n" ] || die "'$n' already exists ($dir/$n)"
    ex="$here/../plugins-examples/hello"
    [ -f "$ex/plugin.json" ] || die "the example plugin is missing ($ex)"
    mkdir -p "$dir/$n"
    for f in plugin.json Main.qml; do
        sed "s/hello/$n/g" "$ex/$f" > "$dir/$n/$f"
    done
    echo "Created $dir/$n"
    echo "Turn it on:  lovelyrice plugin allow $n      (it is your own code, but nothing loads without this step)"
    echo "Edit Main.qml; with /settings -> Plugins -> hot reload on, saving the file reloads it."
}

cmd_allow() {
    need_name "$@"; installed "$1" || die "no plugin '$1' in $dir"
    state_drop "$1"
    state_add "allow $1 $(rev_of "$1")"
    state_add "enable $1"
    echo "'$1' is allowed and enabled."
}
cmd_enable() {
    need_name "$@"; installed "$1" || die "no plugin '$1' in $dir"
    case "$(trust_of "$1")" in
        none)    die "'$1' has never been allowed. Read its code in $dir/$1, then: lovelyrice plugin allow $1" ;;
        changed) die "'$1' changed since you allowed it. Review it, then: lovelyrice plugin allow $1" ;;
    esac
    state_has enable "$1" || state_add "enable $1"
    echo "'$1' enabled."
}
cmd_disable() { need_name "$@"; state_drop "$1" enable; echo "'$1' disabled."; }
cmd_revoke()  { need_name "$@"; state_drop "$1"; echo "'$1': trust withdrawn, and it is off."; }

cmd_update() {
    need_name "$@"; installed "$1" || die "no plugin '$1' in $dir"
    [ -d "$dir/$1/.git" ] || die "'$1' is not a git checkout; nothing to update"
    old=$(rev_of "$1")
    GIT_ALLOW_PROTOCOL=https:ssh:git:file GIT_TERMINAL_PROMPT=0 git -C "$dir/$1" pull --ff-only --quiet || die "git pull failed"
    new=$(rev_of "$1")
    if [ "$old" = "$new" ]; then echo "'$1' is already up to date."; return; fi
    echo "'$1' updated: $old -> $new"
    echo "The code changed, so it stops loading until you review it and allow it again:"
    echo "  git -C $dir/$1 log --stat $old..$new"
    echo "  lovelyrice plugin allow $1"
}

cmd_remove() {
    need_name "$@"
    [ -d "$dir/$1" ] || die "no plugin '$1' in $dir"
    state_drop "$1"
    rm -rf "${dir:?}/$1" "$stdir/plugins/$1.json"
    echo "'$1' removed (folder and stored data)."
}

sub="${1:-list}"; [ $# -gt 0 ] && shift
case "$sub" in
    scan)         cmd_scan ;;
    list|ls)      cmd_list ;;
    info)         cmd_info "$@" ;;
    path)         echo "$dir" ;;
    install)      cmd_install "$@" ;;
    new)          cmd_new "$@" ;;
    allow)        cmd_allow "$@" ;;
    enable)       cmd_enable "$@" ;;
    disable)      cmd_disable "$@" ;;
    revoke)       cmd_revoke "$@" ;;
    update)       cmd_update "$@" ;;
    remove|rm|uninstall) cmd_remove "$@" ;;
    *) echo "lovelyrice plugin: unknown command '$sub' (list, info, install, new, allow, enable, disable, revoke, update, remove)" >&2; exit 2 ;;
esac
