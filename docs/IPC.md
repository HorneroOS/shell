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
| `experience` | `services/Experience.qml` | `get()`, `set(mode)`, `toggle(mode)`, `revert()`, `reset()`, `list()`, `profile(mode)`, `status()`, `customise(mode, field, json)`, `resetCustomisations(mode)`, `setAuto(enabled)`, `deck(mode)`, `setDeckHidden(mode, widget, hide)`, `resetDeck(mode)` — see [Experience modes](#experience-modes) |
| `signal` | `services/Signal.qml` | `reload()` (re-read the live scheme), `mode()` (`dark`/`light`), `theme()` (applied theme id), `previewing()` (true while a Chromatic candidate is shown in memory) |
| `brightness` | `services/Brightness.qml` | `get()`, `getFor(query)`, `set(value)` (+ `setFor` per file) |

## Experience modes

Experience modes (RFC 0001 §5a) are `focus`, `everyday` (default),
`signal`, `gaming` and `studio`. The former `gameMode` target is gone: the
Hyprland effects hook it toggled is now part of the `gaming` mode
(`services/GameMode.qml` follows `experience`), so scripts call
`qs ipc call experience set gaming` / `set everyday` instead.

| Call | Returns |
|---|---|
| `experience get` | active mode id, e.g. `everyday` |
| `experience set <mode>` | `ok: <mode>` or `error: unknown mode: <mode>`; recorded with `source: "cli"` |
| `experience toggle <mode>` | enters `<mode>`, or returns to the previous mode when it is already active |
| `experience revert` | `ok: <mode>` — one-action return to the mode before the last switch (also undoes an automatic switch) |
| `experience reset` | `ok: everyday + cockpit + hornero-signal-night` — factory mode, layout (`horneroctl shell preset apply cockpit --yes`) and theme; per-mode customisations are kept |
| `experience list` | JSON array `[{id, label, description, glyph, active, customised: [field…]}]` |
| `experience profile <mode>` | JSON resolved profile `{id, label, glyph, description, fields: {…}, customised: […], locked: […]}` |
| `experience status` | JSON `{schemaVersion, mode, previous, source, auto, autoEnabled, changedAt, statePath, fields, customised, effective: {…}, unavailable: [field…]}` |
| `experience customise <mode> <field> <json>` | `ok` or `error: …`; `<json>` is a JSON literal (`true`, `2`, `"minimal-top"`), `null` clears the override |
| `experience resetCustomisations <mode>` | `ok` — that mode returns to its factory profile |
| `experience deck <mode>` | JSON `{mode, instruments, catalogue: [id…], hidden: [id…], customised}`: the Signal instrument deck of that mode ([docs/EXPERIENCE.md](EXPERIENCE.md)) |
| `experience setDeckHidden <mode> <widget> <true\|false>` | `ok` or `error: …`; turns one curated instrument off (or back on) for that mode |
| `experience resetDeck <mode>` | `ok` — the mode's deck returns to the factory composition (every display) |
| `experience setAuto <true\|false>` | toggles automatic fullscreen-game switching (off by default); turning it off reverts an automatic switch |

### Profile fields

Every profile has the same fields (factory values in
`services/experience.js`, per-mode overrides in `shell.json`
`experience.modes.<mode>.<field>`):

| Field | Values | Effect |
|---|---|---|
| `motion` | `full` `standard` `reduced` `off` | `Appearance.anim.level`; `appearance.reducedMotion` or the system preference still force `off` |
| `density` | `icons` `values` `labels` | instrumentation density; bars map `icons` to their `glyphs` density |
| `glow`, `scanlines` | bool | luminous accents / scope scanlines; always off in day themes and high contrast; glow also off below `standard` motion |
| `telemetry.rateHz` | 0.2–4 | shared SystemUsage/NetworkUsage poll rate |
| `telemetry.pauseWhenHidden` | bool | pause those providers while a fullscreen window covers the focused output |
| `desktopWidgets` | `none` `user` `instruments` | hide the desktop layer, keep the user's widgets, or add the Signal instrument deck |
| `notifications.hold` | bool | non-critical notifications are filed without a popup; leaving the mode toasts the held count |
| `notifications.suppressFullscreen` | bool | same, only while a fullscreen window is focused |
| `layout.preset`, `layout.apply` | preset id, bool | preferred layout; applied on entry only when `layout.apply` is true (presets rewrite bars) |
| `idle.inhibitFullscreen` | bool | inhibit idle while a fullscreen window is focused |
| `power.suggest` | `""` `performance` `power-saver` | shown as a suggestion; never applied automatically |
| `hooks.hyprlandTuning` | bool | Hyprland animations/blur/gaps/shadows off while active (Hyprland only) |
| `hooks.studioAudio` | bool | on a deliberate switch into the mode (person or `horneroctl mode set`, never auto/startup/reset) runs `horneroctl --json studio audio apply --yes`; leaving the mode, turning the hook off or a reset runs `studio audio revert --yes`. On by default for Studio only. A shell that exits while applied reverts at its next start |

Locked fields ignore overrides: `focus` keeps `glow`/`scanlines` off;
`gaming` keeps `glow`/`scanlines` off and `motion` at `off`.

### State file (contract for `horneroctl mode`)

The active mode is state, not a preference:
`${XDG_STATE_HOME:-~/.local/state}/hornero/experience.json`

```json
{
  "schemaVersion": 1,
  "mode": "everyday",
  "previous": "everyday",
  "source": "user",
  "auto": false,
  "changedAt": "2026-11-16T20:00:00.000Z",
  "studioAudioRestore": ""
}
```

- The shell writes it atomically (temp file + rename) on every switch and
  watches it, so an external atomic write takes effect live.
- A writer outside the shell may write the minimal form
  `{"schemaVersion": 1, "mode": "<mode>", "source": "cli"}`; the shell keeps
  its own `previous` bookkeeping when it next writes. Unknown or malformed
  content is ignored (fail closed) and the current mode stays active.
- `source` is one of `user`, `auto`, `cli`, `reset`, `migration`; `auto: true`
  marks an automatic switch.
- `studioAudioRestore` is the `horneroctl studio mode audio` id the shell
  restores when leaving a mode with `hooks.studioAudio`; empty means the
  shell changed nothing.
- While the shell runs, prefer `qs ipc call experience …` (it validates and
  answers); write the file only when the shell is not running.

A planned `horneroctl mode get|set|list|reset` group maps 1:1 onto
`experience get|set|list|reset`, falling back to the state file when the
shell is not running (`reset` without the shell writes
`{"schemaVersion":1,"mode":"everyday","source":"reset"}` and applies the
cockpit preset and Signal Night theme itself).

## Shell chrome

| Target | Defined in | Functions |
|---|---|---|
| `drawers` | `modules/Shortcuts.qml` | `toggle(drawer)`, `list()`, `state(drawer)` |
| `controlCenter` | `modules/Shortcuts.qml` | `open([pane])`, `close()` |
| `welcome` | `modules/Shortcuts.qml` (controller `modules/welcome/Welcome.qml`) | `open([page])`, `close()`, `status()` |
| `toaster` | `modules/Shortcuts.qml` | `info/success/warn/error(title, message, icon)` |
| `picker` | `modules/areapicker/AreaPicker.qml` | `open()`, `openFreeze()` (+ close variants per file) |
| `lock` | `modules/lock/Lock.qml` | `lock()`, `unlock()` |
| `companion` | `modules/companion/CompanionHost.qml` | `summon()`, `hide()`, `toggle()`, `say(text, timeoutMs)`, `tip()`, `play(animation)`, `setState(state)`, `setSkin(skin)`, `resetPosition()`, `status()`, `ask(text)`, `askStop()`, `approve(runId, decision)`, `clarify(runId, answer)`, `events(runId)` |
| `plugins` | `modules/plugins/PluginHost.qml` | `status()`, `reload()`, `reloadPlugin(id)`, `editDesktop()`, `doneDesktop()`, `toggleEditDesktop()`, `telemetry()` |
| `debug` (first output), `debug.<output>` (every other output) | `modules/drawers/Drawers.qml` | `borders()`, `bars()`, `dump()`, `focusState()` (debug only) |

`debug bars()` returns bar geometry for every connected screen. Each entry has
a `screen` name; bar, island, group, and visual rectangle coordinates are local
to that screen. Use `screen` to group entries rather than treating local
x-coordinates as global desktop positions.

Drawer names accepted by `drawers toggle` are the boolean keys of
`Visibilities` for the active monitor (e.g. `launcher`, `dashboard`,
`controlCenter`, `session`, `sidebar`, `utilities`, `layoutPicker`);
`drawers list` prints them, `drawers state <name>` prints `true`/`false`
(`""` for an unknown name). Unknown names log `[IPC] Drawer "…" does not
exist` and are ignored. Toggles for `launcher`/`session`/`dashboard` are
suppressed while a fullscreen window has focus.

`controlCenter open [pane]` deep-links into a Control Center pane and
returns `opened` or `opened: <pane>`. An unknown pane returns an
`error:` result and does not open Settings. The shell pane registry is the
single validity source used by `horneroctl config gui --pane`. `welcome open [page]`
opens the Welcome Center (`start`, `navigate`, `shell`, `workspaces`,
`personalize`, `tools`, `system`, `learn`, `shortcuts`; unknown pages open `start`
with a warning); `welcome close()` closes it; `welcome status()`
prints JSON (`{"open": bool, "page": string, "showOnLogin": bool}`).
`controlCenter close()` destroys every open Settings window (a no-op when
none is open). Repeated `controlCenter open` calls reuse the single
window and switch its pane instead of stacking duplicates, and the
`controlCenter` custom shortcut toggles the window. The floating window
also closes on `Escape`.

Every opening records the session sighting, so a shell reload in the
same session never auto-reopens. The Welcome window state
itself lives in HorneroOS/hornero (`horneroctl welcome …`); see
`docs/adr/001-welcome.md`.

`companion say <text> [timeoutMs]` shows a timed speech bubble (280
chars max, 6 s default); `tip` shows the next Welcome-linked tip and
also returns it; `play <animation>` one-shots a known animation
(`idle`/`blink`/`look`/`preen`/`stretch`/`hop`/`greet`/`walk`/`hover`/
`takeoff`/`fly`/`land`/`perch`/`peek`/`drag`/`talk`/`think`/`listen`/
`work`/`approve`/`celebrate`/`deny`/`worry`/`error`/`sleep`, unknown
names warn and play `idle`);
`setState <state>` requests a behavior state (unknown states warn and
are ignored) including the reserved future assistant states, which
only change the animation — no backend exists behind them;
`setSkin` keeps the current skin on unknown names; `status()` prints
JSON (`{"enabled", "state", "skin", "animation", "suppressed",
"bubbleOpen", "nestStage", "activityLevel"}`). See `docs/COMPANION.md`.

## Global shortcuts

`modules/Shortcuts.qml` wires `CustomShortcut` (`components/misc/`,
a `GlobalShortcut`) entries for bar, launcher, dashboard, utilities, etc.
Compositor-side bindings live in HorneroOS/config, not here.

## Process (outbound) contracts

The shell also *spawns* processes; the stable outbound contracts are:

- Appearance (native first, see `docs/NATIVE-APPEARANCE.md`):
  `gsettings set/get org.gnome.desktop.interface …` (via
  `services/GtkSettings.qml`) and the Hornero Signal live scheme file
  `${XDG_STATE_HOME:-~/.local/state}/hornero/signal/scheme.json`
  (schema v2, watched and, for built-ins, written by `services/Signal.qml`).
- Appearance uses the shared native Hornero CLI contract:
  `horneroctl appearance theme apply <id> --yes`,
  `horneroctl appearance gtk …`, `horneroctl appearance hyprland --yes`,
  `horneroctl appearance hyprlock --yes`.
- Optional integrations: `horneroctl capture record start/stop/pause --yes`,
  `horneroctl wallpaper current`, `horneroctl wallpaper set --yes`,
  `horneroctl shell preset apply --yes`,
  `horneroctl appearance night-mode toggle --yes`,
  `notify-send …`, `systemctl …`, and the configured terminal from
  `Config.general.apps.terminal` (Kitty by default) through `app2unit` when
  available, with a direct-launch fallback.
