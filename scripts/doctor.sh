#!/bin/sh
# LovelyRice tool check.
#   doctor.sh            machine-readable: status<TAB>kind<TAB>command<TAB>package<TAB>feature   (used by the shell)
#   doctor.sh --text     human-readable table with an install command at the end
# status = ok|missing   kind = req|opt   package "-" means "not in the Arch repos, install it yourself"

mode="${1:-tsv}"

have() {   # have "a|b" -> true when any alternative is installed
    old_ifs=$IFS; IFS='|'
    for c in $1; do
        IFS=$old_ifs
        case "$c" in
            font:*)  fc-list 2>/dev/null | grep -qi "${c#font:}" && return 0 ;;
            ldmp)    command -v ldmp >/dev/null 2>&1 || [ -x "$HOME/.local/bin/ldmp" ] && return 0 ;;
            *)       command -v "$c" >/dev/null 2>&1 && return 0 ;;
        esac
        IFS='|'
    done
    IFS=$old_ifs
    return 1
}

table() { cat <<'TABLE'
req	qs	quickshell	The shell itself (Qt 6.5+)
req	hyprctl	hyprland	Workspaces, windows, /windows, /keys, overview
opt	font:JetBrains Mono	ttf-jetbrains-mono	The font LovelyRice is designed around
opt	notify-send	libnotify	Notifications from screenshots, timers and this check
opt	wl-copy	wl-clipboard	Copying: calculator, emoji, /clip, screenshots
opt	cliphist	cliphist	/clip clipboard history
opt	grim	grim	Screenshots and the blurred lock screen
opt	slurp	slurp	Region screenshots and recordings
opt	wf-recorder	wf-recorder	/record
opt	brightnessctl	brightnessctl	Sidebar brightness slider
opt	wpctl	wireplumber	/control: audio devices and mic
opt	powerprofilesctl	power-profiles-daemon	/control: power profile
opt	upower	upower	Battery in the sidebar
opt	nmcli	networkmanager	/network
opt	bluetoothctl	bluez-utils	/bluetooth
opt	magick|convert	imagemagick	Colors from the wallpaper
opt	curl	curl	Weather in the dashboard
opt	xdg-open	xdg-utils	Opening web searches and links
opt	fprintd-verify	fprintd	Fingerprint unlock on the lock screen
opt	hyprlock	hyprlock	Fallback lock screen if the built-in one fails
opt	foot	foot	Terminal that follows the theme (running windows recolor live)
opt	fastfetch	fastfetch	Themed system info: `lovelyrice fetch` and the terminal greeting
opt	gsettings	glib2	GTK apps follow the theme (dark/light switch and live reload)
opt	ldmp	-	/music integration (install ldmp yourself)
TABLE
}

report() {
    table | while IFS="$(printf '\t')" read -r kind cmd pkg feat; do
        if have "$cmd"; then s=ok; else s=missing; fi
        printf '%s\t%s\t%s\t%s\t%s\n' "$s" "$kind" "$cmd" "$pkg" "$feat"
    done
}

if [ "$mode" = "--text" ]; then
    report | while IFS="$(printf '\t')" read -r s kind cmd pkg feat; do
        mark="✓"; [ "$s" = ok ] || mark="✗"
        tag=""; [ "$kind" = req ] && tag=" (required)"
        printf '  %s  %-22s %s%s\n' "$mark" "$(echo "$cmd" | sed 's/^font://; s/|/ or /')" "$feat" "$tag"
    done
    pk=$(report | awk -F'\t' '$1=="missing" && $4!="-" {print $4}' | sort -u | tr '\n' ' ')
    if [ -n "$pk" ]; then
        echo
        echo "Install what is missing:"
        echo "  sudo pacman -S --needed $pk"
    else
        echo
        echo "Everything LovelyRice can use is installed."
    fi
    report | awk -F'\t' '$1=="missing" && $4=="-" {print "  (also missing: " $3 " - " $5 ")"}'
else
    report
fi
