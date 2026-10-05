# HorneroOS shell

Hornero Shell is the official HorneroOS desktop shell for Wayland, built with
[Quickshell](https://quickshell.org/), QML, and Qt 6. Hyprland is its supported
compositor; Niri integration is experimental. The shell provides bars,
launcher, dashboard, Control Center, notifications, lock screen, and
wallpaper/theme pipeline, plus a native `Hornero` C++ plugin for
performance-critical work (image analysis, audio, calculator).

![Hornero desktop](docs/assets/desktop-hero.png)

*Pre-release snapshot from the graphical test VM (1280×720).*

## Position in HorneroOS

- **This repo owns**: the shell runtime (`shell.qml`, `modules/`,
  `services/`, `config/`, `utils/`, `components/`), shell-owned visual
  assets (`assets/`), the native plugin (`plugin/`) and helper (`extras/`),
  vendored layout presets (`presets/`), and Nix/CMake packaging.
- **Does not own**: compositor/terminal/app defaults
  ([HorneroOS/config](https://github.com/HorneroOS/config)), distribution
  composition ([HorneroOS/hornero](https://github.com/HorneroOS/hornero)),
  user overrides (`~/.config/hornero`, theme/wallpaper data), or external
  CLIs: the shell calls `horneroctl` by bare name for operating-system
  capabilities (see `docs/INTEGRATION.md`).

## Status

Under active development; shell changes ship through reviewed HorneroOS
preview candidates. Operating-system operations use the Hornero CLI contract,
and Appearance uses the shared Hornero pipeline. Extraction history and
upstream attribution are documented in `docs/PROVENANCE.md`.

## Build

```bash
cmake -S . -B build -D DISTRIBUTOR="local"
cmake --build build
```

Requires CMake ≥ 3.19, Qt 6.9+ (Core, Qml, Gui, Quick, Concurrent, Sql,
Network, DBus), `libqalculate`, `pipewire`, `aubio`, `libcava`/`cava`.
`VERSION`/`GIT_REVISION` come from git tags when available, else default
to `0.0.0`/`unknown` with a warning. Select modules with
`-D ENABLE_MODULES="extras;plugin;shell"`.

Nix: `nix build .#hornero-shell` (see `flake.nix`, `nix/`).

## Test / lint

```bash
python3 -m pytest tests/ -q        # layout, appearance, IPC, path + static scans
pre-commit run --all-files          # portable lint subset (see below)
./scripts/check_personal_data.sh    # personal-data guard
./scripts/check_forbidden_paths.sh  # no chezmoi/personal-path regressions
```

## Run

```bash
# CMake install (default INSTALL_QSCONFDIR=etc/xdg/quickshell/hornero):
QML2_IMPORT_PATH=<install-prefix>/usr/lib/qt6/qml \
  qs -p <install-prefix>/etc/xdg/quickshell/hornero
# Nix layout installs the QML tree to <prefix>/share/hornero-shell
# instead — or just run the `hornero-shell` wrapper.
qs ipc call <target> <fn> …                  # see docs/IPC.md
```

Runtime paths follow XDG and the `hornero` namespace. Explicit service knobs
include `HORNERO_WALLPAPERS_DIR`, `HORNERO_RECORDINGS_DIR`, and
`HORNERO_LIB_DIR` (see `docs/ARCHITECTURE.md`).

## Provenance

The original extraction source and upstream license are recorded in
`docs/PROVENANCE.md` and `NOTICE`.

## Structure

```text
shell.qml presets/ modules/ services/ config/ utils/ components/ assets/
plugin/ extras/ nix/ tests/ scripts/ docs/ CMakeLists.txt flake.nix
```

## License

Dual layout (see `NOTICE`): scaffold and project docs are
[MIT](LICENSE); the shell runtime, native code, and presets are
[GPL-3.0-only](LICENSE.GPL-3.0) (derived from
[caelestia-dots/shell](https://github.com/caelestia-dots/shell) by
[@soramane](https://github.com/soramane) — credit preserved).
