#!/bin/sh
# Builds the glass refraction shader: shaders/glass.frag -> shaders/glass.frag.qsb
# Qt can only load shaders that were compiled with `qsb` (package qt6-shadertools on Arch). Without the .qsb file, glass still
# works (blurred, tinted, lit rim) but the rim does not bend what is behind it.
#   build-shaders.sh           build, and say what happened
#   build-shaders.sh --quiet   build, print nothing unless it fails (what install.sh uses)
#   build-shaders.sh --check   exit 0 when the shader is built and up to date
here=$(cd "$(dirname "$0")/.." && pwd)
src="$here/shaders/glass.frag"
out="$here/shaders/glass.frag.qsb"
mode="${1:-}"

[ -f "$src" ] || { echo "lovelyrice: $src is missing" >&2; exit 1; }
if [ "$mode" = "--check" ]; then [ -f "$out" ] && [ ! "$src" -nt "$out" ]; exit $?; fi

qsb_bin=""
for c in qsb qsb6 qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb /usr/lib/x86_64-linux-gnu/qt6/bin/qsb /opt/qt6/bin/qsb; do
    if command -v "$c" >/dev/null 2>&1; then qsb_bin=$(command -v "$c"); break; fi
    [ -x "$c" ] && { qsb_bin="$c"; break; }
done
if [ -z "$qsb_bin" ]; then
    [ "$mode" = "--quiet" ] && exit 0
    echo "lovelyrice: qsb not found, so glass will blur but not bend what is behind it." >&2
    echo "            sudo pacman -S --needed qt6-shadertools      then:  lovelyrice shaders" >&2
    exit 1
fi

# the shell's folder may be read-only (the packaged copy in /usr/share): build there only if we can write, else the per-user copy
if [ ! -w "$here/shaders" ]; then
    [ "$mode" = "--quiet" ] && exit 0
    echo "lovelyrice: $here/shaders is not writable. Build it as root, or use the package's build step." >&2
    exit 1
fi

if log=$("$qsb_bin" --qt6 -o "$out" "$src" 2>&1); then
    [ "$mode" = "--quiet" ] || echo "Built $out - glass now bends what is behind it (the shell picks it up by itself)."
else
    rm -f "$out"
    echo "lovelyrice: building the glass shader failed:" >&2
    echo "$log" >&2
    exit 1
fi
