#!/bin/sh
# Links this folder into ~/.config/quickshell/lovelyrice and the `lovelyrice` command into ~/.local/bin.
# (Installing the package from packaging/ does the same system-wide instead.)
set -e
src="$(cd "$(dirname "$0")" && pwd)"
dest="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/lovelyrice"
bin="$HOME/.local/bin"

mkdir -p "$(dirname "$dest")" "$bin"
ln -sfn "$src" "$dest"
ln -sf "$src/bin/lovelyrice" "$bin/lovelyrice"
chmod +x "$src/bin/lovelyrice" "$src/scripts/"*.sh "$src/hooks-examples/"*.sh 2>/dev/null || true

echo "Linked $dest"
echo "Linked $bin/lovelyrice"
case ":$PATH:" in *":$bin:"*) ;; *) echo "Note: $bin is not in your PATH." ;; esac
sh "$src/scripts/build-shaders.sh" --quiet 2>/dev/null || true   # glass refraction shader, if qsb is installed
echo
sh "$src/scripts/doctor.sh" --text
echo
echo "Start it with:  lovelyrice start     (or: qs -c lovelyrice)"
