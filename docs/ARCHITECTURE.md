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

## Compositor integration

Hyprland is the primary production backend today, but it is an implementation
choice rather than Hornero Shell's identity. A capability-aware compositor
facade and Niri adapter route shared workspace, window, keyboard-layout, idle
display-power, and layer-focus behavior. Backend-specific differences and
capability boundaries are tracked in [Compositor integration](COMPOSITORS.md).

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

The shell's design language is Hornero Signal (RFC 0001). Surfaces read
colour only through `Signal.palette.<role>` (`services/Signal.qml`), type and
geometry through `Appearance.font/rounding/spacing/padding`, motion through
`Appearance.anim.curves/durations`, and icons through `Glyph { name }`
(bundled Hornero Glyphs font). Themes are complete role tables: three
built-ins ship in `Signal.qml`, catalogue themes come from HorneroOS/config
packs with a schema-v2 palette and are applied by `horneroctl`, which writes
the live scheme the shell watches
(`$XDG_STATE_HOME/hornero/signal/scheme.json`). Wallpapers never recolour the
UI. The pipeline also coordinates the wallpaper pointer, GTK theme and
colour-scheme policy and icons; the latest selection wins. Pack-owned assets
are never downloaded automatically. See
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
