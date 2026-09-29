# Compat adapters — dots-* dependencies

Every `dots-*` helper the shell shells out to is an **external runtime CLI**
owned outside this repo. The shell must keep working (possibly degraded)
when one is missing, must never hard-require a dotfiles checkout, and must
never grow new `dots-*` coupling without a row here. Dispositions A–G are
defined in `docs/MIGRATION.md` §2.

## Adapter rules

1. Call CLIs by bare name (`dots-gtk-theme`, not `$HOME/…` paths), except
   the two legacy `$HOME/.local/bin/…` absolute paths (`dots-m3-colors`,
   `dots-wallpaper-current`) kept for dotfiles-era `$PATH` setups — new code
   uses bare names.
2. Absence must degrade, not crash: guard with `FileView` fallbacks
   (wallpaper pointer), empty-model fallbacks (theme/scheme lists), or
   error signals (`ThemePipeline.lastError`).
3. Appearance path is fixed: QML calls **only** `dots-gtk-theme` /
   `dots-m3-colors` for GTK/M3 application, `dots-color-scheme` for scheme
   ops, and `dots-appearance theme list` for theme-pack listing. Never
   `gtk-theme-manager.sh` directly, never bare `python3 generate-m3-colors`,
   never bare `python3` for theme listing
   (`tests/test_appearance_consistency.py`).
4. Markers: coupling points carry `TODO(hornero-compat)` pointing here.

## Per-CLI notes

| CLI | Fallback when missing | Marker |
|---|---|---|
| `dots-gtk-theme` | Appearance apply fails the job with `lastError`; shell keeps running | `services/ThemePipeline.qml` |
| `dots-m3-colors` | Preview/apply colours fail the job; cached `scheme.json` still loads | `services/ThemePipeline.qml`, `services/Wallpapers.qml` |
| `dots-color-scheme` | Scheme lists render empty; mode/variant actions no-op | `services/Colours.qml`, `services/ThemePipeline.qml` |
| `dots-accent-override` | Accent section actions no-op | `ColorVariantSection.qml` |
| `horneroctl` (missing/failed `shell preset list`) | Grid falls back to the empty state with the store-path hint; stale `current` pointers select nothing | `modules/layoutpicker/PresetGrid.qml` |
| `dots-wallpaper-current` | `FileView` on `Paths.wallpaperPointer` seeds `actualCurrent` | `services/Wallpapers.qml` |
| `horneroctl wallpaper set --yes` | Random-wallpaper launcher action fails if `horneroctl` is missing (shell cannot run without it) | `config/LauncherConfig.qml` |
| `dots-night-mode` | Quick-toggle action no-ops | `QuickToggles.qml`, `SystemPane.qml` |
| `dots-recorder` | Recording actions no-op | `services/Recorder.qml` |
| `horneroctl apps switcher apply-theme-pack`, `horneroctl appearance hyprlock` | Theme side effects fail without failing the apply job (fire-and-forget processes) (`\|\| true` semantics) | `services/ThemePipeline.qml` |
| `dots-theme-selector`, `dots-lockscreen`, `dots-screenshooter`, `dots-sysupdate`, `dots-keyboard-help` | Launched actions fail silently in terminal/launcher | `SystemPane.qml`, `LauncherConfig.qml` |
| `dots-appearance theme list` | Theme search list renders empty when absent (JSON-parse fallback) | `modules/launcher/services/Themes.qml` (`TODO(hornero-compat)`) |

## Debt to resolve in follow-ups

- (G, resolved track 3a) `Themes.qml` loader: theme listing moved behind the
  `dots-appearance theme list` CLI (bare-`python3` call dropped). The
  theme-pack registry itself is still dots-owned tooling; a HorneroOS-owned
  data source remains a follow-up (see `docs/GTK-PACK-OWNERSHIP.md`).
- Normalize the two legacy `$HOME/.local/bin` absolute CLI paths to bare
  names once `$PATH` guarantees hold on HorneroOS images.
- Promote this table into versioned per-CLI contracts with the owning
  HorneroOS repos as they are extracted.
