# LovelyRice roadmap

Built in phases so each one can be tested before the next starts.

## Phase 1 — Palette power-ups + ldmp  ✅
`=` calculator (and auto-detected sums) · `?` web search · `:` emoji picker · `/windows` switcher ·
`/kill` · `/timer` · `/todo` · `/screenshot` · `/screenshot-full` · `/record` (+ sidebar indicator) ·
`/music` (ldmp first, any MPRIS player) · media keys through IPC.

## Phase 2 — Connectivity, auto-lock, scheme maker  ✅
Network and Bluetooth (sidebar icons + `/network`, `/bluetooth`), auto-lock/suspend with settings, `/scheme-maker`.
Also fixed: `/windows`, the terminal choice for ldmp, the `/clip` rich-text warning.

## Phase 2b — Control center  ✅ (this version)
`/control` quick settings: switch audio output/input, mic mute, do-not-disturb, power profile (and unmute apps).
Media popout (cover art, seek bar) in the same fly-out style as the volume popout: on track change, on hover over the
sidebar media widget, or `ipc call rice media`. Notification bell with an unread-count badge (right-click = do-not-disturb)
and per-app mute (`mute` on a popup or in the history; `/control` lists muted apps to unmute). Battery time remaining
(hover the icon) and a low-battery warning (configurable, with a critical second warning).
Also added: a vertical **brightness slider** in the sidebar (drag, click or scroll).

## Phase 3 — Theming  ✅ (this version)
**Wallpaper-derived palettes:** `/match-wallpaper` (or `/settings` → *Match colors to current wallpaper*) builds a scheme from the
current wallpaper and saves it as the user theme `wallpaper`; *Colors follow the wallpaper* redoes it whenever the wallpaper
changes. **Theme hooks:** executables in `~/.config/lovelyrice/hooks/` run after every theme/wallpaper change with `LR_*` color
variables (`hooks-examples/kitty.sh`). **Theme editor:** `/settings` → *Edit colors* opens the scheme maker (live preview).
**Animation speed:** off / fast / normal / slow in `/settings`.

## Phase 4 — Session  ✅ (this version)
Dim before auto-lock (last 15 s, any input cancels), lock when the lid closes (and on waking from sleep). Lock screen:
blurred screenshot background, caps-lock badge, media controls, battery, optional fingerprint unlock (fprintd).

## Phase 5 — Overview and dashboard  ✅ (this version)
`SUPER + TAB` overview with live window previews. Hover dashboard (weather, resource graphs, mini calendar) on the sidebar
clock. `/keys` cheat sheet built from the binds Hyprland actually has loaded.

## Phase 6 — Distribution and ldmp  ✅ (this version)
**`lovelyrice` command** (`start`, `stop`, `restart`, `open <mode>`, `theme`, `doctor`, `ipc ...`), **PKGBUILD** in `packaging/`,
**`/doctor`** and a one-time first-run notice for missing tools, **palette preferences** (search engine, `?w` / `?aw` / `?gh`
search shortcuts and your own in `config.json`, calculate-as-you-type on/off, app ranking on/off, forget launch history).
**ldmp / MPRIS:** shuffle and repeat buttons in the media popout and in `/music` (any player that exposes them), cover art
falls back to `cover.jpg` / `folder.jpg` next to the playing file.
ldmp itself (separate zip, `ldmp_mpris.zip`) now exports cover art (`mpris:artUrl`, embedded or `cover.jpg` in the folder),
`xesam:url`, writable `Shuffle`, `LoopStatus` and `Volume`. ldmp reports repeat as `Track`, otherwise `Playlist` (it always wraps).

## Phase 7 — Themed apps and identity  ✅ (this version)
**Built-in theme sync** (`scripts/theme-sync.sh`): foot terminals recolor live, GTK 3/4 named colors + dark/light + live reload, a generated
fastfetch config, `colors.sh` for scripts. 16 terminal colors made from the theme (`LR_C0..15`). **`lovelyrice setup`** wires it into
`foot.ini`, `gtk.css` and your shell (marked blocks, `--remove` undoes it). **Greeting:** `lovelyrice greet` / `fetch` — fastfetch with the cat.
**Logo:** the cat (`assets/logo.svg`, `Logo.qml`) replaces the "LR" text and follows the theme. `/sync-apps`, `lovelyrice sync|setup|fetch|greet|colors|logo`.

## Phase 8 — Layout, tabs, fuzzy, schemes, Hyprland sync  ✅ (this version)
Sidebar modules reorderable and individually hideable (`sidebarOrder`). Settings split into tabs. Fuzzy matching (`Fuzzy.js`) across the palette.
29 new schemes (39 total). `HyprSync.qml`: event-driven Hyprland refresh fixes the startup / special-workspace / app-icon "needs /reload" bugs.
