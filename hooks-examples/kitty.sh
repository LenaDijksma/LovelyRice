#!/bin/sh
# Example LovelyRice theme hook: recolor running kitty windows.
# Install:  mkdir -p ~/.config/lovelyrice/hooks && cp kitty.sh ~/.config/lovelyrice/hooks/ && chmod +x ~/.config/lovelyrice/hooks/kitty.sh
# Needs `allow_remote_control yes` (or socket-only) in kitty.conf. LovelyRice passes the colors as LR_* variables.
kitty @ set-colors --all --configured \
    background="$LR_BG" foreground="$LR_FG" cursor="$LR_ACCENT" \
    selection_background="$LR_ACCENT" selection_foreground="$LR_BG" \
    color1="$LR_ACCENT" color2="$LR_ACCENT2" color3="$LR_WARN" color4="$LR_ACCENT" color5="$LR_ACCENT2" \
    color8="$LR_DIM" 2>/dev/null
