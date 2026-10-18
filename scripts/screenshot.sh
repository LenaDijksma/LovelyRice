#!/bin/sh
# Usage: screenshot.sh [region|screen]
# Saves to ~/Pictures/Screenshots, copies to the clipboard, shows a notification.
# Needs: grim slurp wl-clipboard   (sudo pacman -S grim slurp wl-clipboard)
# Esc or right-click while selecting a region cancels.

mode="${1:-region}"
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y%m%d_%H%M%S).png"

sleep 0.4   # let the palette fade out before capturing

if [ "$mode" = screen ]; then
    grim "$file" || exit 1
else
    region=$(slurp -d -b '#00000066' -c '#ffffffff' -w 2) || exit 0
    grim -g "$region" "$file" || exit 1
fi
wl-copy < "$file"
notify-send -a Screenshot -i "$file" "Screenshot saved" "$file (copied to clipboard)"
