# IPC surface — HorneroOS/shell

Quickshell IPC (`qs ipc call <target> <fn> [args…]`). Targets are declared
with `IpcHandler` in the listed QML files. This document is the contract
other HorneroOS components script against; renames must update
`tests/test_ipc_mapping.py` in the same commit.

## Services

| Target | Defined in | Functions |
|---|---|---|
| `wallpaper` | `services/Wallpapers.qml` | `get()`, `set(path)`, `list()` |
| `appearance` | `services/ThemePipeline.qml` | `applyTheme(id, wallpaper)`, `reload()`, `setWallpaper(path)` |
| `mpris` | `services/Players.qml` | `getActive(prop)`, `list()`, `play()` (+ pause/next/previous per file) |
| `notifs` | `services/Notifs.qml` | `clear()`, `isDndEnabled()`, `toggleDnd()` (+ per-file extras) |
| `idleInhibitor` | `services/IdleInhibitor.qml` | `isEnabled()`, `toggle()`, `enable()` (+ `disable()` per file) |
| `hypr` | `services/Hypr.qml` | `refreshDevices()`, `cycleSpecialWorkspace(direction)`, `listSpecialWorkspaces()` |
| `gameMode` | `services/GameMode.qml` | `isEnabled()`, `toggle()`, `enable()`, `disable()` |
| `colours` | `services/Colours.qml` | `reload()`, `mode()`, `flavour()` |
| `brightness` | `services/Brightness.qml` | `get()`, `getFor(query)`, `set(value)` (+ `setFor` per file) |

## Shell chrome

| Target | Defined in | Functions |
|---|---|---|
| `drawers` | `modules/Shortcuts.qml` | `toggle(drawer)`, `list()` |
| `controlCenter` | `modules/Shortcuts.qml` | `open()` |
| `toaster` | `modules/Shortcuts.qml` | `info/success/warn/error(title, message, icon)` |
| `picker` | `modules/areapicker/AreaPicker.qml` | `open()`, `openFreeze()` (+ close variants per file) |
| `lock` | `modules/lock/Lock.qml` | `lock()`, `unlock()` |
| `debug` | `modules/drawers/Drawers.qml` | `borders()`, `dump()` (debug only) |

Drawer names accepted by `drawers toggle` are the boolean keys of
`Visibilities` for the active monitor (e.g. `launcher`, `dashboard`,
`controlCenter`, `session`, `sidebar`, `utilities`, `layoutPicker`);
`drawers list` prints them. Unknown names log `[IPC] Drawer "…" does not
exist` and are ignored. Toggles for `launcher`/`session`/`dashboard` are
suppressed while a fullscreen window has focus.

## Global shortcuts

`modules/Shortcuts.qml` wires `CustomShortcut` (`components/misc/`,
a `GlobalShortcut`) entries for bar, launcher, dashboard, utilities, etc.
Compositor-side bindings live in HorneroOS/config, not here.

## Process (outbound) contracts

The shell also *spawns* processes; the stable outbound contracts are:

- Appearance: `dots-m3-colors …`, `dots-gtk-theme -q …`,
  `dots-color-scheme …` (see `docs/COMPAT.md`, disposition A).
- Optional integrations: `dots-recorder start/stop/pause`,
  `dots-wallpaper-current`, `dots-wallpaper-set …`,
  `dots-quickshell preset list/apply`, `dots-night-mode toggle`,
  `notify-send …`, `systemctl …`, `foot -e sh -c …`.
