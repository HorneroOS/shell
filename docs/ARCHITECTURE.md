# Hornero Shell architecture

Hornero Shell is the Wayland desktop runtime built with Quickshell, QML, Qt 6,
and a small native plugin. It owns the bars, launcher, dashboard, Control
Center, notifications, wallpaper presentation, session surfaces, lock UI, and
Companion.

## Ownership

- **HorneroOS/shell** owns presentation, live session state, interaction, and
  accessibility behavior. `services/` coordinates session state; `modules/`
  and `components/` render it; `config/` provides typed settings; `utils/`
  contains shared runtime helpers.
- **HorneroOS/hornero** owns the stable CLI, operating-system actions, shared
  file contracts, and catalogue resolution.
- **HorneroOS/config** owns factory defaults, packaged application settings,
  theme and wallpaper data, and materialization.
- **HorneroOS/docs** owns user and developer documentation. The website
  consumes reviewed pins and product data.

The current data flow is: Shell interaction → Shell service → Shell IPC or
`horneroctl` capability → user-owned XDG state. Packaged defaults and media are
read-only inputs; they are never modified by a running session.

## Configuration and paths

The Shell uses one XDG namespace, `hornero`, via `utils/Paths.qml`:

| Data | User path |
| --- | --- |
| Shell settings | `$XDG_CONFIG_HOME/hornero/shell.json` |
| Theme packs, presets, wallpapers | `$XDG_DATA_HOME/hornero/` |
| Wallpaper pointer and notification state | `$XDG_STATE_HOME/hornero/` |
| Generated palettes and image caches | `$XDG_CACHE_HOME/hornero/` |

Unset XDG variables use their standard home-relative directories. System
catalogues are read from XDG data directories; runtime writes stay in user
locations. See [PATH_CONTRACT.md](PATH_CONTRACT.md).

## Appearance flow

Theme catalogue metadata comes from HorneroOS/config packs. The Shell presents
the catalogue and previews, then submits a validated apply request. The shared
pipeline coordinates the Shell palette, selected mode, wallpaper, GTK theme and
color-scheme policy, icons, and generated color roles. Wallpaper-derived color
generation is cached and debounced; the latest selection wins. Pack-owned
assets are never downloaded automatically. See
[theme data ownership](theme-split-plan.md) and
[native appearance](NATIVE-APPEARANCE.md).

## Settings and navigation

`PaneRegistry.qml` is the canonical Control Center destination registry. It
provides labels, categories, searchable metadata, and pane components. Shell IPC
opens destinations from Welcome, the CLI, keyboard shortcuts, and in-product
links. Appearance section metadata lives with Appearance Settings.

## Validation

QML lint, Python contract tests, V tests in HorneroOS/hornero, config validation,
and graphical Hornero QA cover the product boundary. UI acceptance uses real
keyboard/pointer interaction and rendered screenshots; deterministic system
checks prove state and package contents. See [IPC](IPC.md),
[Layouts](LAYOUTS.md), and [VM testing](VM_TESTING.md).
