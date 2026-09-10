# Native appearance layers — HorneroOS/shell issue #2

QML applies theming through native layers first and keeps `dots-*` CLIs
only as thin, debt-marked compat adapters. Every remaining compat call site
carries a `TODO(hornero-compat)` marker pointing here or at
`docs/COMPAT.md`.

## Native layers

### GtkSettings (`services/GtkSettings.qml`) — migration step (a)

Applies GTK themes, icon themes, and color-scheme policy through the
deterministic `gsettings` desktop APIs before falling back to
`dots-gtk-theme`.

Policy mapping (`toGsettingsScheme`, input normalized by
`ThemePipeline.normalizeGtkColorScheme`):

| Policy | `org.gnome.desktop.interface color-scheme` |
|---|---|
| `prefer-light` | `prefer-light` |
| `prefer-dark` | `prefer-dark` |
| `default` | `default` |
| `follow` (or empty) | `prefer-dark` when dark mode, else `prefer-light` |

Native writes:

| Request | `gsettings set` keys |
|---|---|
| GTK theme | `org.gnome.desktop.interface gtk-theme`, `org.gnome.desktop.wm.preferences theme` |
| Icon theme | `org.gnome.desktop.interface icon-theme` |
| Color scheme | `org.gnome.desktop.interface color-scheme` |

Live queries (`refreshLive`) read the same three keys back into
`liveGtkTheme` / `liveIconTheme` / `liveColorScheme`. When `gsettings` is
absent (exit 99) the layer falls through to the `dots-gtk-theme` compat
adapter (`_compatFor`); theme-pack ids with no explicit GTK theme always
use the compat path because id resolution is dots-owned tooling.

Consumers: `ThemePipeline` (queued gtk/gtk-color-scheme/icons jobs and the
pipeline finalize step via `applyFull`), `AppearancePane` (live seeding via
`refreshLive` plus change connections; its `dots-gtk-theme` live queries
yield whenever a native value exists).

### WallpaperAnalysis (`services/WallpaperAnalysis.qml`) — migration step (b)

Thin wrapper around the native `ImageAnalyser` plugin exposing
`dominantColour` / `luminance` plus `ready` and `isLight` helpers for any
wallpaper path via `analyze(path)`.

Consumers: `Wallpapers.preview()` (instant preview tone alongside the full
M3 palette job), `Colours.wallLuminance` / `Colours.wallDominantColour`
(translucency layering and native tone), `AppearancePane.previewAnalyser`
(an `ImageAnalyser` bound to the palette-generation input; the preview pane
shows its dominant colour as an instant swatch while the generated palette
is absent).

## Migrated call sites

| Former call site | Native replacement |
|---|---|
| `ThemePipeline` finalize script (`dots-gtk-theme theme/apply/set-icons/color-scheme/sync-color-scheme`) | `GtkSettings.applyFull` |
| `ThemePipeline` standalone `dots-gtk-theme apply` | `GtkSettings.applyGtkTheme` |
| `ThemePipeline` standalone `dots-gtk-theme color-scheme` | `GtkSettings.applyColorScheme` |
| `ThemePipeline` standalone `dots-gtk-theme set-icons` (`iconOnlyProc`, removed) | `GtkSettings.applyIconTheme` |
| `AppearancePane` live current GTK/icon/color-scheme queries | `GtkSettings.refreshLive` first; `dots-gtk-theme` queries yield when native values exist |
| Wallpaper tone for translucency | `Colours.wallLuminance` (already native) plus new `wallDominantColour` |
| Wallpaper preview tone | `WallpaperAnalysis` (`Wallpapers`) and `previewAnalyser` (`AppearancePane`) |

## Remaining compat adapters (with reasons)

| Call site | CLI | Reason native is not yet deterministic |
|---|---|---|
| `ThemePipeline.m3Proc`, `Wallpapers` preview colours, `AppearancePane.previewPaletteProc` | `dots-m3-colors` | Full M3 palette generation needs materialyoucolor, which lives outside this repo |
| `ThemePipeline` scheme regenerate/sync-state; `Colours.setMode`; `Schemes` list/current/set; `M3Variants`; `AppearancePane` scheme/mode commits | `dots-color-scheme` | Owns scheme persistence and the palette store; no native store exists yet |
| `GtkSettings` full-mode with theme-pack id | `dots-gtk-theme theme` | Theme-pack id resolution is dots-owned tooling |
| `GtkThemeSection` / `IconThemeSection` listings | `dots-gtk-theme -p list/icons` | Native directory scan needs index.theme parsing plus de-dup across system/user roots |
| `AppearancePane` live queries (fallback branch) | `dots-gtk-theme -p current*` | Hosts without `gsettings` |
| `ThemePipeline` side effects | `dots-snappy-switcher`, `dots-hyprlock-theme` | Dots-owned tooling with no native equivalent |
| `Themes.qml` loader | bare `python3 …/list-themes.py` | Pre-existing disposition-G debt, out of scope for issue #2 |

Out of scope for issue #2 (unchanged): `dots-accent-override`,
`dots-quickshell`, `dots-wallpaper-current` / `dots-wallpaper-set`,
`dots-night-mode`, `dots-recorder`, and launcher-only actions
(`dots-theme-selector`, `dots-settings-gui`, `dots-lockscreen`,
`dots-screenshooter`, `dots-sysupdate`, `dots-keyboard-help`).

## Contracts and checks

- `gtk-theme-manager.sh` is never called from QML and bare
  `python3 generate-m3-colors` never runs — enforced by
  `tests/test_appearance_consistency.py` and
  `scripts/check_forbidden_paths.sh`.
- The same test file requires both native layers to exist and every
  remaining `dots-gtk-theme` / `dots-m3-colors` / `dots-color-scheme` QML
  call site to carry a `TODO(hornero-compat)` marker.
- Outbound process contracts are documented in `docs/IPC.md`; the `dots-*`
  dependency table in `docs/MIGRATION.md` §2 records the native-first
  status per CLI.
