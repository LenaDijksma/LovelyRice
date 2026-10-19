#!/bin/sh
# Drag-select a region, save it to ~/Pictures/Screenshots, copy it to the clipboard, show a notification.
# Needs: grim slurp wl-clipboard   (sudo pacman -S grim slurp wl-clipboard)
# Esc or right-click while selecting cancels.

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y%m%d_%H%M%S).png"

region=$(slurp -d -b '#00000066' -c '#ffffffff' -w 2) || exit 0
grim -g "$region" "$file" || exit 1
wl-copy < "$file"
notify-send -a Screenshot -i "$file" "Screenshot saved" "$file (copied to clipboard)"
