# LovelyRice plugins

A plugin is a folder of QML in `~/.config/lovelyrice/plugins/<name>/`. It can add a **utility bar module**, **palette commands**
(`/foo`) and a **dropdown tab**. Hooks (`~/.config/lovelyrice/hooks/`) stay what they were: shell scripts that run after a theme change.

## Trust: read this first

A plugin is arbitrary QML running inside your desktop shell **with your full permissions**: it can read your files, run programs and use
the network. The `provides` list in `plugin.json` says what a plugin is meant to add; it is documentation, **not a sandbox**.

- `lovelyrice plugin install <git-url>` only clones it, prints where the code came from, and loads **nothing**.
- A plugin loads only after you run `lovelyrice plugin allow <name>` (or press Enter twice on it in `/settings` → Plugins).
- Allowing pins the git commit. `lovelyrice plugin update <name>` that brings new code switches the plugin off until you review it and allow it again.
  Local edits to a checkout are not tracked (you are the author); plugins that are not git checkouts are never re-checked.
- Only install code you have read.

## Quick start

```
lovelyrice plugin new mything        # copies plugins-examples/hello
lovelyrice plugin allow mything      # your own code, but still an explicit step
```

Then the bar module, a `/mything` palette command and a dropdown tab appear. In `/settings` → Plugins, switch on *Reload a plugin when its
files change* while developing.

## Layout

```
~/.config/lovelyrice/plugins/<name>/
    plugin.json
    Main.qml
```

```json
{
  "name": "example",
  "version": "0.1.0",
  "description": "What it does",
  "entry": "Main.qml",
  "provides": ["barModule", "paletteCommand", "dropdownCard"]
}
```

`name` must equal the folder name (lowercase letters, digits, `-`, `_`). `entry` is optional (default `Main.qml`), a relative `.qml` path.

## Main.qml

The root must be a `Scope` with `property var api`; LovelyRice fills `api` in before anything else runs. Everything else is optional.

```qml
import QtQuick
import Quickshell

Scope {
    id: root
    property var api

    property Component barModule: Component { Item { implicitWidth: 30; implicitHeight: 30 /* ... */ } }
    property var paletteCommands: [ { name: "foo", desc: "Does foo", takesArgs: true, run: function (args) { /* ... */ } } ]
    property string dropdownTitle: "Foo"
    property Component dropdownCard: Component { Item { implicitHeight: 120 /* ... */ } }
}
```

`plugins-examples/hello/` is a complete working example of all three.

### Extension points

| | What you define | Where it shows up |
|---|---|---|
| Bar module | `barModule`: a Component. Set `implicitWidth` / `implicitHeight`; it is put in a pill like the built-in modules. Use `api.horizontal` to lay out along a top/bottom bar. | `/settings` → Bar as `name (plugin)`; a new one goes in front of the clock, move it like any module. Visible while the plugin is on. |
| Palette command | `paletteCommands`: `[{ name, run(args), desc, icon, keywords, takesArgs }]`. `name` is lowercase letters, digits, `-`. With `takesArgs`, Enter on `/name` waits for text and Enter runs `run("the text")`. Built-in command names win. | `/name` in the palette |
| Dropdown card | `dropdownCard`: a Component that gets the panel's width and should set `implicitHeight`. `dropdownTitle` names the tab. | a tab in the dropdown, ordered in `/settings` → Dropdown |

A plugin that is switched off or removed leaves no module, command or tab behind.

### The `api` object

| | |
|---|---|
| `api.name` | the plugin's name |
| `api.bg surface fg dim accent accent2 warn font radius radiusSmall` | the theme, live: bind to them |
| `api.dur(ms)` | an animation duration scaled by the user's animation speed |
| `api.barPosition horizontal barThickness cell iconSize`, `api.fs(n)` | the utility bar, live |
| `api.notify(summary, body, urgency)` | a notification (`"low"`, `"normal"`, `"critical"`) |
| `api.exec(cmd)` | run a command, fire and forget |
| `api.run(cmd, callback)` | run a command; `callback(exitCode, stdout)`. `cmd` is an array (no shell) or a string (`sh -c`) |
| `api.get(key, fallback)` `api.set(key, value)` `api.remove(key)` | small JSON values kept per plugin in `~/.local/state/lovelyrice/plugins/<name>.json`. They load a moment after start, so call `get` inside bindings: they update when the data arrives |
| `api.log(msg)` | console log, prefixed with the plugin name (`lovelyrice log`) |

## CLI

```
lovelyrice plugin list | info <name> | path
lovelyrice plugin install <git-url>       # clone only; loads nothing
lovelyrice plugin new <name>
lovelyrice plugin allow <name>            # trust (pins the git commit) and turn on
lovelyrice plugin enable|disable <name>   # needs allow first
lovelyrice plugin revoke <name>           # withdraw the trust (also turns it off)
lovelyrice plugin update <name>           # git pull; new code = allow again
lovelyrice plugin remove <name>           # deletes the folder and its stored data
lovelyrice plugin status                  # what is running, with load errors (shell must be running)
lovelyrice plugin reload                  # look at the folder again now
```

The same commands work without the shell running (`scripts/plugins.sh`); a running shell picks changes up by itself.
State is in `~/.local/state/lovelyrice/plugins.state`. IPC: `ipc call rice pluginStatus` and `pluginsReload`.

## Hot reload and its limit

With *Reload a plugin when its files change* on, the plugin folder is checked every two seconds and a changed plugin is unloaded and loaded
again. Qt caches QML files by name, so this re-reads **`Main.qml`** only. If you split a plugin over several `.qml` files, run
`lovelyrice reload` (restarts the shell) after editing those.

## Not in this version

Settings pages, IPC functions and theme hooks as plugin extension points (the plan's "later" list), and a per-plugin permission model.
