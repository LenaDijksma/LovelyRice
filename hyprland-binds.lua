-- LovelyRice keybinds for hyprland.lua (Hyprland 0.55+).
--
-- 1. Remove any existing tap-SUPER bind (old launcher, Caelestia's caelestia:launcher, ...):
--      hyprctl binds | grep -i -B3 -A8 super_l
--    then hl.unbind("<exact keys as originally written>")  -- case-sensitive
--    Also delete any "SUPER + catchall" bind left over from Caelestia.
-- 2. Use ONE tap-SUPER option (A, then B if A does nothing). Reload Hyprland, tap SUPER and watch
--    the terminal running `qs -c lovelyrice`. You should see "LovelyRice: palette ..." lines.

-- Option A (from the Hyprland wiki): release bind on SUPER
hl.bind("SUPER + SUPER_L", hl.dsp.global("lovelyrice:palette"), { release = true })

-- Option B: release bind, ignore modifier state
-- hl.bind("SUPER + SUPER_L", hl.dsp.global("lovelyrice:palette"), { release = true, ignore_mods = true })

-- Option C: bare key
-- hl.bind("SUPER_L", hl.dsp.global("lovelyrice:palette"), { release = true })

-- Option D: skip the global-shortcut protocol and call the shell directly
-- hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice toggle"), { release = true })

-- Autostart (in your hyprland.lua):  hl.exec_cmd("lovelyrice start")      -- same as `qs -c lovelyrice`
-- Every `qs -c lovelyrice ipc call rice <fn>` below can be written `lovelyrice <command>` (see `lovelyrice help`).

-- Normal shortcuts (work regardless of the option above)
hl.bind("SUPER + SPACE",       hl.dsp.global("lovelyrice:palette"))
hl.bind("SUPER + SHIFT + T",   hl.dsp.global("lovelyrice:themes"))
hl.bind("SUPER + SHIFT + W",   hl.dsp.global("lovelyrice:wallpapers"))
hl.bind("SUPER + ALT + C",     hl.dsp.global("lovelyrice:calendar"))
hl.bind("SUPER + ALT + S",     hl.dsp.global("lovelyrice:settings"))
hl.bind("SUPER + TAB",         hl.dsp.global("lovelyrice:overview"))   -- workspace overview with live previews
hl.bind("SUPER + SHIFT + N",   hl.dsp.global("lovelyrice:nextTheme"))

-- Screenshots and recording (also /screenshot, /screenshot-full, /record in the palette):
-- hl.bind("Print",         hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice screenshot region"))
-- hl.bind("SHIFT + Print", hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice screenshot screen"))
-- hl.bind("SUPER + Print", hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice record false"))
-- Media keys also work with LovelyRice's player choice (ldmp or whatever is playing):
-- hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice music toggle"))
-- hl.bind("XF86AudioNext", hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice music next"))
-- hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice music prev"))

-- Quick settings (also /control in the palette):
-- hl.bind("SUPER + ALT + Q",      hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice control"))
-- hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice mic"))
-- hl.bind("SUPER + ALT + D",      hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice dnd"))
-- hl.bind("SUPER + ALT + P",      hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice powerProfile"))
-- hl.bind("SUPER + ALT + M",      hl.dsp.exec_cmd("qs -c lovelyrice ipc call rice media"))   -- show the media popout

-- Lock screen (also available as /lock). Optional shortcut:
-- hl.bind("SUPER + ALT + L", hl.dsp.global("lovelyrice:lock"))
-- Auto-lock / lock before sleep with hypridle (hypridle.conf):
--   general { lock_cmd = qs -c lovelyrice ipc call rice lock; before_sleep_cmd = qs -c lovelyrice ipc call rice lock }
