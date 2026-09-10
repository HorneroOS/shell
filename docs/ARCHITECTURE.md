# Architecture — HorneroOS/shell

Quickshell + QML + Qt6 desktop shell for Wayland (Hyprland-first).
Imported from `ulises-jeremias/dotfiles@b26db04`; see `MIGRATION.md`.

## Entry point

`shell.qml` (`ShellRoot`): mounts `Background`, `Drawers`, `AreaPicker`,
`Lock`, `Shortcuts`, `BatteryMonitor`, `IdleMonitors`. Pragmas pin
`QS_NO_RELOAD_POPUP=1`, threaded render loop, and flickable deceleration.

## Layers

| Layer | Paths | Role |
|---|---|---|
| Shell root | `shell.qml` | Composition only |
| Modules | `modules/` | Visible surfaces: bar, launcher, dashboard, controlcenter, lock, notifications, osd, session, sidebar, utilities, drawers, background, areapicker, layoutpicker, windowinfo |
| Services | `services/` | Singletons: `ThemePipeline`, `Colours`, `Wallpapers`, `Audio`, `Brightness`, `Hypr`, `Network`/`Nmcli`, `Notifs`, `Players`, `Recorder`, `SystemUsage`, `Weather`, `Time`, `Visibilities`, `GameMode`, `IdleInhibitor`, `VPN`, `ThemePipeline` |
| Config | `config/` | `Config.qml` + per-area `*Config.qml`; user-tunable knobs |
| Shared UI | `components/` | Reusable controls/containers/effects (`qs.components*`) |
| Helpers | `utils/` | `Paths`, `SysInfo`, `Icons`, `Images`, `Searcher`, `Strings`, `NetworkConnection`, JS (`fuzzysort.js`, `fzf.js`) |
| Assets | `assets/` | Logo, gifs, shaders, `wrap_term_launch.sh`, `pam.d/` samples |
| Native | `plugin/`, `extras/` | `Hornero` QML plugin (C++: image analysis, audio, calculator, models) + `version` helper |
| Data | `presets/` | 11 vendored layout presets (fallback for `dots-quickshell preset list`) |

## Runtime / config path model

No chezmoi, no hardcoded home layouts. Resolution order everywhere is
**explicit env override → XDG → `$HOME` default**, centralized in
`utils/Paths.qml` (singleton, `qs.utils`):

| Path | Override | Default |
|---|---|---|
| Shell data (themes, wallpapers) | `DOTS_DATA_DIR` | `$XDG_DATA_HOME/dots` → `~/.local/share/dots` |
| Shell state (wallpaper pointer) | `DOTS_STATE_DIR` | `$XDG_STATE_HOME/dots` → `~/.local/state/dots` |
| Shell cache (smart-colors, imagecache) | `DOTS_CACHE_DIR` | `$XDG_CACHE_HOME/dots` → `~/.cache/dots` |
| Shell user config | `DOTS_CONFIG_DIR` | `$XDG_CONFIG_HOME/hornero` → `~/.config/hornero` |
| Pictures / videos | `XDG_PICTURES_DIR` / `XDG_VIDEOS_DIR` | `~/Pictures`, `~/Videos` |
| Wallpapers dir | `HORNERO_WALLPAPERS_DIR` | `Config.paths.wallpaperDir` (absolute-resolved) |
| Recordings dir | `HORNERO_RECORDINGS_DIR` | `~/Videos/Recordings` |
| Native helper lib | `DOTS_LIB_DIR` / `HORNERO_LIB_DIR` | `/usr/lib/hornero` |
| XKB rules (dev/nix) | `HORNERO_XKB_RULES_PATH` | system xkeyboard-config |

System defaults vs user overrides:

- **System defaults** ship under the Quickshell config dir
  (`INSTALL_QSCONFDIR`, default `etc/xdg/quickshell/hornero`): QML tree,
  `presets/`, `LICENSE.GPL-3.0`, `NOTICE`.
- **User overrides** live outside this repo: per-user `shell.json`-style
  settings under the config dir above and theme/wallpaper data under the
  data dir. The shell watches them (`FileView`, `watchFiles`) and
  live-reloads; a preset apply deep-merges into the user file, never into
  the shipped tree.
- `assets/pam.d/*` are **host-integration samples**, not installed to
  `/etc` by CMake. Distributors copy/adapt them in packaging.

## Theming pipeline

`services/ThemePipeline.qml` serializes appearance jobs (theme / wallpaper /
reload) and shells out **only** to the canonical CLIs `dots-m3-colors`
(color generation) and `dots-gtk-theme` (GTK apply), plus
`dots-color-scheme` (scheme state). It never invokes
`gtk-theme-manager.sh` directly and never runs bare
`python3 generate-m3-colors` (enforced by
`tests/test_appearance_consistency.py`). Theme data resolves from
`Paths.data/themes`, wallpapers from `Paths.data/wallpapers`, with
`Paths.pictures/Wallpapers` as the user-content root.

## External coupling

All `dots-*` runtime CLI dependencies, their dispositions (A–G), fallback
behavior, and debt markers are inventoried in `docs/COMPAT.md`.
The Quickshell IPC surface (targets other components script against) is in
`docs/IPC.md`. Contributor rules for QML/Qt/IPC/Process usage are in
`AGENTS.md`.
