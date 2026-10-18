# Packaging

```
cd packaging
makepkg -si          # builds from this checkout, installs /usr/bin/lovelyrice and /usr/share/lovelyrice
```

Then add `exec-once = lovelyrice start` (or `hl.exec_cmd("lovelyrice start")` in the Lua config) to your autostart and
run `lovelyrice doctor` to see which optional tools you still need.

Before publishing to the AUR: set `url` and `license` in the PKGBUILD, add a LICENSE file, and switch `source=()` to a
release tarball (with `sha256sums`) so the package no longer depends on a local checkout.
