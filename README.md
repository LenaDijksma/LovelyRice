# LovelyRice

Keyboard-first Quickshell shell for Hyprland. Floating rounded sidebar, launcher + command palette,
built-in wallpaper renderer, JSON themes.

## Install
```
pacman -S quickshell ttf-jetbrains-mono   # needs Qt 6.5+
./install.sh                              # links the shell and the `lovelyrice` command
lovelyrice doctor                         # shows which optional tools you still need
lovelyrice start
```
Or build the package: `cd packaging && makepkg -si` (installs `/usr/bin/lovelyrice` and `/usr/share/lovelyrice`).
Start it with the rest of your autostart programs: `lovelyrice start` (same as `qs -c lovelyrice`).

## The `lovelyrice` command
`lovelyrice start | stop | restart | status | log` · `sync` `setup` `fetch` `greet` `colors` `logo` · `toggle` `settings` `calendar` `lock` `overview` `dashboard` `control` `media` `keys`
`network` `bluetooth` · `open <mode>` (palette on `scheme`, `clip`, `doctor`, ...) · `theme <name|next>` · `screenshot [region|screen]`
· `record [region]` · `music [toggle|next|prev]` · `dnd` `mic` `power-profile` `match-wallpaper` `run-hooks` · `ipc <function> [args]`
(any function of the `rice` IPC target) · `doctor` · `version`. It finds the shell through `$LOVELYRICE_DIR`, the `install.sh` link,
its own folder or `/usr/share/lovelyrice`, so it works from a checkout and from the package. Use it in keybinds instead of the long
`qs -c lovelyrice ipc call rice ...` form (both keep working).

## /doctor
`/doctor` (or `lovelyrice doctor`, or `/settings` → *Check installed tools*) lists every tool LovelyRice can use, what it enables, and
whether it is installed. Enter on a missing tool copies its `sudo pacman -S --needed ...` command; the first row copies one command
for everything missing. The first time LovelyRice runs it also sends a single notification saying how many optional tools are missing
(it never repeats; delete `~/.local/state/lovelyrice/first-run-done` to see it again).

## Keybinds
See `hyprland-binds.lua` (Hyprland 0.55+ Lua config). It has several ways to bind tap-SUPER (A–D) plus
normal shortcuts like `SUPER + SPACE`. Every shortcut prints a `LovelyRice: ...` line to the shell log,
so you can tell whether Hyprland delivered it. `hyprctl globalshortcuts` should list `lovelyrice:*`.
`hyprctl binds | grep -i super_l` shows what else owns SUPER.

> Hyprland 0.55+ parses `hyprctl dispatch` as Lua; LovelyRice uses `hl.dsp.focus({ workspace = "N" })`
> for workspace clicks and `hl.dsp.exit()` for /logout (uwsm: change to `uwsm stop` in `CommandPalette.qml`).

## Launcher + commands
- Just type to search apps (frequently used ones rise to the top). Enter launches.
- Type `/` for commands: `/scheme` `/wallpaper` `/lock` `/sleep` `/logout` `/reboot` `/power` `/reload`
- ↑/↓ or Ctrl+N/P · Tab completes · Esc goes back/closes
- `/scheme` previews live; Esc reverts. `/wallpaper` shows thumbnails.
- `/logout`, `/reboot`, `/power` need Enter twice.

## Sidebar
- Workspaces show a **generic outline icon for the kind of app** inside them — browser, files, terminal, game, code,
  chat, mail, music, video, image, docs, system, or a plain window (count badge when there are several windows;
  a dot for empty ones). Edit the lists in `AppCategory.qml` to reclassify an app. Only occupied/focused workspaces are listed.
- When a **special workspace** is open on a monitor (scratchpads like `communication`, `music`, `todo`, `special`,
  `sysmon`), a pill slides in above the workspaces showing its icon/name. Click it to close it again.
- **Volume / brightness**: flying popouts slide out of the sidebar whenever the value changes (works with your
  existing XF86 binds). Brightness reads `/sys/class/backlight` (laptop panels; external monitors via DDC aren't supported).
- **Brightness slider**: a vertical slider under the status icons. Drag or click the track, scroll to nudge by 5%.
  It appears on laptops (a backlight in `/sys/class/backlight`) and sets the level with `brightnessctl`. Hide it in `/settings`.
  Brightness keys still work and still fly out the popout; moving the slider itself doesn't (you can already see it).
- **Battery** icon fills with charge, shows a bolt and pulses while charging. **Hover it for the time remaining.**
  A low-battery notification appears at the level set in `/settings` → *Battery* (default 20%), and a critical one at half of that.
- **Notification bell** with an unread-count badge (counts what arrived while the history panel was closed, including
  do-not-disturb). Click = history panel, right-click = do-not-disturb on/off.
- **Media popout**: cover art, title/artist, previous/play/next and a seek bar fly out next to the media widget when the
  track changes and while you hover the widget (or the popout). `qs -c lovelyrice ipc call rice media` shows it on demand.

## Network and Bluetooth (phase 2)
- Sidebar icons for network (Wi-Fi strength, ethernet, or off) and Bluetooth (dim when off, accent when a device is
  connected). Click one to open `/network` or `/bluetooth` in the palette. Both can be hidden in `/settings`.
- **`/network`** (or `/wifi`): turn Wi-Fi on/off, rescan, connect. Saved and open networks connect straight away;
  a new secured network asks for the password (hidden as you type). Enter on the connected network disconnects,
  Ctrl+D forgets a saved one. Uses `nmcli` (NetworkManager).
- **`/bluetooth`** (or `/bt`): power, scan, connect/disconnect, pair new devices, Ctrl+D removes one. Uses `bluetoothctl` (bluez-utils).

## Theming (phase 3)
- **Colors from the wallpaper:** `/match-wallpaper` makes a scheme from the current wallpaper (dark base, the most vivid hue
  as accent, a second hue as accent2) and activates it as the theme `wallpaper`. Turn on *Colors follow the wallpaper* in
  `/settings` to redo it on every wallpaper change. Needs ImageMagick (`magick` or `convert`). Fine-tune the result in `/scheme-maker`.
- **Theme hooks:** put executable scripts in `~/.config/lovelyrice/hooks/`; they run (in parallel) about a second after the
  theme or wallpaper changes, with `LR_THEME LR_WALLPAPER LR_BG LR_SURFACE LR_FG LR_DIM LR_ACCENT LR_ACCENT2 LR_WARN` set
  (`#rrggbb`). `hooks-examples/kitty.sh` recolors running kitty windows (foot, GTK and fastfetch are handled by the built-in sync, see *Themed apps*). Hooks run for saved changes, not for `/scheme`
  browsing previews. `ipc call rice runHooks` runs them now; switch them off in `/settings`.
- **Theme editor:** `/settings` → *Edit colors (scheme maker)…* (same as `/scheme-maker`, live preview).
- **Animation speed:** `/settings` → off / fast / normal / slow. "off" also stops the pulsing battery, recording and lock animations.

## Sidebar layout, tabs, fuzzy search (phase 8)
- **Move the sidebar modules around:** `/settings` → *Sidebar* lists every module in order (logo, workspaces, flexible gap, media, status icons,
  brightness, buttons, recording indicator, clock). `←`/`→` (or the ▲ ▼ buttons) move the selected one, `Enter` shows or hides it. The *flexible gap*
  is the stretchy space that pushes everything after it to the bottom; move it to change where the sidebar splits. Saved in `settings.json` as `sidebarOrder`.
- **Settings tabs:** Sidebar · Theme · Popouts · Power · Launcher. `Tab` / `Shift+Tab` (or `1`-`5`, or click) switch tabs.
- **Fuzzy search:** the palette matches letters in order, not just substrings: `vsc` finds Visual Studio Code, `tg` Telegram, `thfm` Thunar File Manager.
  Prefix and word-start matches rank first; launch history still breaks ties. Works in apps, `/` commands, `/scheme`, `/wallpaper`, `/windows`, `/kill`, `/clip`, `/todo`, `/network`, `/bluetooth`, `/keys`, `/doctor`.
- **39 color schemes** (29 new): dracula, one-dark, solarized dark/light, monokai, ayu dark/light, catppuccin latte/frappe/macchiato, gruvbox-light,
  rose-pine dawn/moon, tokyo-night storm/light, nord-light, everforest-light, github dark/light, material-ocean, oxocarbon, synthwave, sakura, mint, ocean,
  midnight, coffee, lovelyrice, hacker. `/scheme` previews them live. Your own are still just JSON files in `~/.config/lovelyrice/themes/`.
- **Workspace fixes:** `HyprSync.qml` refreshes Hyprland's state at startup (until Hyprland answers) and after every window / workspace / special-workspace
  event, so workspace icons, app icons and special-workspace icons show up without `/reload`. The workspace list is only rebuilt when it actually changes.

## Themed apps and the cat (phase 7)
LovelyRice now themes more than itself. After every theme or wallpaper change (and a few seconds after startup) a built-in sync
(`scripts/theme-sync.sh`) writes everything below to `~/.local/state/lovelyrice/generated/` and recolors what is running.
Switch it off in `/settings` → *Sync apps with the theme* (with separate switches for GTK and foot), re-run it with `/sync-apps` or `lovelyrice sync`.

**One-time hookup:** `lovelyrice setup` (or `setup foot`, `setup gtk`, `setup greet`). It edits nothing else, every edit is a marked block,
and `lovelyrice setup --remove` takes it all out again.

- **foot:** running foot windows are recolored in place the moment the theme changes (terminal escape codes sent to each window, so it
  works with `foot --server` too). New windows read `~/.config/foot/lovelyrice-colors.ini`, which `setup foot` includes from `foot.ini`
  (a `[colors]` section of your own in `foot.ini` wins for new windows; the greeting below still recolors them).
  The 16 terminal colors are made from the theme: red/green/blue/magenta/cyan share the accent's saturation and lightness, and the theme's own
  accent, accent2 and warn colors take the slot they are closest to (gruvbox keeps its red and yellow). Light themes get a light palette.
- **GTK 3 and 4:** the generated `gtk.css` defines libadwaita's and Adwaita's named colors (window, view, headerbar, card, sidebar, accent,
  success/warning/error, selection...). `setup gtk` creates `~/.config/gtk-{3,4}.0/lovelyrice.css` and imports it from your `gtk.css`.
  The dark/light preference follows the theme (`color-scheme`), and running apps reload when the colors change.
  Works for libadwaita apps and for the Adwaita or adw-gtk3 GTK themes; other GTK 3 themes ignore these names.
  Qt apps are not covered (use qt6ct with the generated `colors.sh` if you want that).
- **Greeting on launch:** `setup greet` adds a block to `.bashrc` / `.zshrc` / fish `conf.d` so every new foot window first applies the theme
  colors and then shows **fastfetch with the LovelyRice cat** (`lovelyrice greet`; `LR_NO_FETCH=1` keeps the colors but skips the fastfetch).
  Run it by hand with `lovelyrice fetch`. The config is `generated/fastfetch.jsonc`; the cat is `assets/cat.pix` (a pixel grid, `1` = face,
  `2` = nori tab) turned into half-block characters in the accent colors, so it also works in any other truecolor terminal.
- **The logo:** the sidebar shows the cat from `assets/logo.svg` instead of the "LR" text. `Logo.qml` draws the same paths, so body, ears and tail = accent and
  the nori tab = accent2 (the eyes are cut out) and it fades with the theme like everything else (hide it in `/settings` as before). `lovelyrice logo` prints the path of a
  recolored `logo.svg` for notifications, icons or a README.
- **For your own scripts and hooks:** hooks now also get `LR_C0`…`LR_C15` (the terminal colors) and `LR_LIGHT`, and `generated/colors.sh` can be
  sourced from anywhere (`. ~/.local/state/lovelyrice/generated/colors.sh`). The built-in sync runs first, then your hooks.
  Needs: `foot`, `fastfetch`, `glib2` (gsettings) — `/doctor` lists them.

## /control (phase 2b)
`/control` is the quick-settings list: **Do not disturb**, **Microphone** mute, **Power profile** (Enter cycles power-saver →
balanced → performance), every **audio output** and **input** (Enter makes it the default) and any **muted app** (Enter
unmutes). Needs `wireplumber` (`wpctl`) for device switching and `power-profiles-daemon` (`powerprofilesctl`) for profiles;
rows that don't apply to your machine are simply missing. Shortcuts for keybinds: `ipc call rice control`, `mic`, `dnd`,
`powerProfile` (see `hyprland-binds.lua`).

**Per-app mute:** hover a notification popup or a history entry and press `mute`. Muted apps get no popups and don't add to
the unread count, but still appear in the history (marked *muted*). Critical notifications always get through, for muted apps
and for do-not-disturb. The list is saved in `~/.local/state/lovelyrice/notif-muted.json`.

## Overview, dashboard, keys (phase 5)
- **Overview** (`SUPER + TAB`, `/overview`, `ipc call rice overview`; add the bind from `hyprland-binds.lua`): one tile per
  workspace that has windows, plus the current one (up to 9), with live previews of the windows on the focused monitor.
  Click a window to focus it, click a tile to switch, arrows/Tab to pick, Enter to go, `1`–`9` to jump, Esc to close.
  A window that can't be captured shows its title instead of a preview.
- **Dashboard:** hover the sidebar clock (click it for the full calendar) to fly out weather, CPU / memory / network graphs
  (the last two minutes) and a mini calendar with today's events from your iCal feeds. `/dashboard` or `ipc call rice dashboard`
  shows it for a few seconds. Turn it off in `/settings`.
- **Weather is opt-in** (`/settings` → *Weather in the dashboard*) because it asks wttr.in, which sees your IP address.
  It picks your location by IP unless `~/.config/lovelyrice/config.json` has `"weather": { "location": "Hengelo" }`.
  Metric or imperial in `/settings`. Needs `curl`.
- **`/keys`:** a searchable list of your keybinds, read from `hyprctl binds -j`, so it always matches the config that is
  actually loaded (`ipc call rice keys` opens it directly). Modifiers are shown as SUPER / CTRL / ALT / SHIFT.

## Session (phase 4)
- **Dim before lock:** with auto-lock on, the screen fades to dark for the last 15 seconds; touching anything brings it back.
  The dim overlay ignores the pointer, so it never gets in the way.
- **Lock on lid close:** `/settings` → *Lock when the lid closes* (off by default). Reads `/proc/acpi/button/lid/*/state` or logind.
  It also locks when the machine wakes from sleep, so a suspend you didn't trigger from LovelyRice still ends up locked.
  Your system's own lid action (suspend / ignore) is unchanged, set that in `logind.conf`.
- **Lock screen:** a blurred screenshot of what you were looking at (or the wallpaper, if you turn *Blurred screenshot* off),
  a CAPS badge when caps lock is on (read from the keyboard LED), media controls, and the battery level at the top right.
- **Fingerprint:** turn on *Fingerprint unlock* in `/settings`. Needs `fprintd` and an enrolled finger (`fprintd-enroll`).
  The lock screen then says to touch the reader; typing your password still works. It gives up quietly if there is no reader.

## Auto-lock and sleep
`/settings` → *Lock and sleep*: lock automatically after N minutes idle, optionally suspend after M minutes, and
lock before sleeping (also used by `/sleep`). It uses Wayland idle detection, so a video player or browser that
inhibits idle keeps the screen awake. You no longer need hypridle for locking (running both is fine).

## /scheme-maker
Opens a colour editor with live preview on the real shell. Pick a row (Background, Surface, Text, Accent...),
move the Hue/Saturation/Lightness sliders or type a hex code, or let it **Generate** a palette from your accent or
make a **Random** one. `←/→` change hue (Shift = saturation, Ctrl = lightness), Enter edits the hex, `Ctrl+S` saves.
Saved to `~/.config/lovelyrice/themes/<name>.json` and shown in `/scheme`; Esc cancels and restores your theme.
A file in that folder with a built-in theme's name overrides it. Delete the file to remove a scheme.

## Terminal for ldmp
`/music` → "Open ldmp" now uses your own terminal: the one picked in `/settings`, else `$TERMINAL`, else the
terminal you currently have open, else the first installed modern one (konsole, gnome-terminal and xterm only if nothing else exists).

## Palette preferences (phase 6)
`/settings` → *Palette*: **web search engine** (DuckDuckGo, Google, Brave, Startpage, Ecosia, Kagi, Bing, or your own),
**calculate as you type** (off = only after `=`), **put frequently used apps first**, and *Forget app launch history*.
**Search shortcuts:** `?w tea` Wikipedia · `?aw hyprland` Arch wiki · `?aur`, `?pac` packages · `?gh` GitHub · `?yt` YouTube ·
`?map` OpenStreetMap · `?g` Google · `?ddg`. Add your own, or a custom engine, in `~/.config/lovelyrice/config.json`
(`%s` marks where the text goes; without it the text is appended). Only `http(s)` URLs are accepted:
```
"search": { "url": "https://search.example.org/?q=%s", "bangs": { "docs": "https://docs.example.org/?q=%s" } }
```
With a `url` set, *custom* appears in the engine list.

## Palette extras (phase 1)
Everything below lives in the palette — tap SUPER, then:
- **Calculator:** type `2+2*3`, `(1+2)^3` or `= sqrt(16)+pi`. Enter copies the result.
- **Web search:** `?arch wiki hyprland` opens the search in your browser (engine: `searchUrl` in `CommandPalette.qml`).
- **Emoji:** `:smile` or `/emoji`. Enter copies the emoji.
- **`/windows`:** jump to any open window. **`/kill`:** end one of your processes (Enter twice).
- **`/timer 10m tea`:** countdown with a notification (`1h30m`, `90s`, or a bare number = minutes).
- **`/todo`:** type a task and Enter to add, Enter on a task to tick it, Ctrl+D to delete.
- **`/screenshot`** (region) and **`/screenshot-full`**, saved to `~/Pictures/Screenshots` and copied.
  **`/record`** and **`/record-region`** save to `~/Videos/Recordings`; a red timer shows in the sidebar, click it or run `/record` again to stop.
- **`/music`:** play/pause, next/previous, seek, volume, shuffle and repeat, and "Open ldmp". It controls whatever is playing,
  otherwise ldmp. The sidebar media widget follows the same choice. Media keys: see `hyprland-binds.lua`.
  Shuffle / repeat (also as buttons in the media popout) appear when the player exposes them over MPRIS. Cover art comes from the
  player (`mpris:artUrl`); if there is none, a `cover` / `folder` / `front` / `album` image (jpg, png, webp) next to the playing
  file is used, so ldmp shows covers without any changes to ldmp.

Tools used: `grim slurp wl-clipboard` (screenshots, copy), `wf-recorder` (recording), `cliphist` (/clip), `libnotify` (notify-send),
`brightnessctl` (brightness slider), `upower` (battery), `wireplumber` (`wpctl`, /control), `power-profiles-daemon` (/control power profile), `imagemagick` (colors from the wallpaper), `curl` (optional weather).
Roadmap for the next phases: `ROADMAP.md`.

## Lock screen
`/lock` (or `lovelyrice:lock`, or `qs -c lovelyrice ipc call rice lock`) locks every monitor with a Wayland
session lock: your wallpaper, a big clock and a password card. The password is checked through PAM
(`pam/lovelyrice` includes your system `system-auth`). For auto-lock, point hypridle's `lock_cmd` at the IPC call.
**Test it with a spare TTY open (Ctrl+Alt+F3) the first time.** If the shell ever crashes while locked,
Hyprland keeps the session locked; log in on the TTY and restart Hyprland or run `hyprlock` from there.
If the lock screen fails to load, `/lock` falls back to `hyprlock` when it is installed.

## Popups
Only one popup (palette, calendar, settings) is open at a time. SUPER closes whichever is open instead of
opening another palette. While a popup is open, and for a moment after, a special workspace that appears by
itself is closed again (this stops the focus handover from re-opening a hidden scratchpad).

## Settings
`/settings` (or `SUPER + ALT + S`) opens a popup to change the sidebar live — width, edge gap, left/right side,
corner radius, and which widgets are shown (logo, workspaces, media, CPU/memory, volume, brightness slider, battery, network,
Bluetooth, notification bell, buttons, clock) — plus the low-battery warning, the volume/brightness popouts and the media popout. Keys: ↑↓ select, ←→ change, Enter toggle, Esc close; mouse works too.
Saved to `~/.local/state/lovelyrice/settings.json`.

## Calendar
`/calendar`, clicking the clock, or `lovelyrice:calendar` opens a month view + agenda.
Keys: arrows move, PgUp/PgDn month, `t` today, `r` refresh, `g` open that day in Google Calendar, Esc closes.

Link a calendar by creating `~/.config/lovelyrice/config.json` (see `config.example.json`):
Google Calendar → Settings → your calendar → *Integrate calendar* → **Secret address in iCal format**.
That URL gives read-only access to the calendar, so keep it private. Any `.ics` URL or local file path works,
and recurring events are expanded. Events with a time zone different from this machine's are shown in local clock time.

## Wallpapers
LovelyRice draws the wallpaper itself (cross-fade, every monitor) — no swww/hyprpaper needed.
**Stop any other wallpaper program** or the two will fight over the background layer.
Images go in `~/Pictures/Wallpapers` (or `./wallpapers`). With none selected you get a gradient in the theme colors.

## Themes
`void` `violet` `paper` `tokyo-night` `catppuccin` `gruvbox` `rose-pine` `nord` `kanagawa` `everforest`.
Drop a JSON file in `themes/` (colors, `font`, `opacity`, `shadow`, optional `wallpaper`).
Corner radius is the same for every theme (`Theme.radius`). State lives in `~/.local/state/lovelyrice/`.

## Layout
`Theme` · `Usage` · `Card` (rounded + shadow) · `Pill` · `Ring` · `Sidebar` · `CommandPalette` · `Wallpaper`
· widgets: `Workspaces` `Media` `SystemStats` `Audio` `BrightnessSlider` `Battery` `NotifWidget` `Clock`
· services: `Brightness` `Control` `Power` `Notifs` `Music` `Search` `Doctor` · popouts: `Osd` `MediaPopout`
· `Logo` (the cat) · `Hooks` (sync + hooks) · `assets/` (logo.svg, cat.pix) · `bin/lovelyrice` (CLI) · `scripts/doctor.sh` `theme-sync.sh` `setup.sh` · `packaging/PKGBUILD`
