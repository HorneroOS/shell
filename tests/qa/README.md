# Shell QA suites

Tests only — no QML feature code. Run:

```bash
python3 -m pytest tests/test_gui_smoke.py tests/test_cli_gui_sync.py \
  tests/test_extension_compat.py tests/test_persistence_restart.py -q
```

## What runs where

| Suite | Needs | If missing |
|---|---|---|
| [test_gui_smoke.py](../test_gui_smoke.py) structural (qmllint + pane registry) | Qt6 `qmllint` | skip = NOT RUN |
| [test_gui_smoke.py](../test_gui_smoke.py) screenshot (`tests/qa/run_gui_smoke.py`) | live Wayland + `qs` + `grim` | skip = NOT RUN, never faked |
| [test_cli_gui_sync.py](../test_cli_gui_sync.py) | `horneroctl` on PATH | skip = NOT RUN |
| [test_extension_compat.py](../test_extension_compat.py) | `scripts/validate_plugin.py` | runs anywhere |
| [test_persistence_restart.py](../test_persistence_restart.py) | `horneroctl`, isolated HOME/XDG | skip = NOT RUN |

## NOT RUN scenarios (declared, never PASS)

- Headless screenshots: no weston/sway/cage compositor is installed on the
  dev host, so pixel smoke is NOT RUN outside a Wayland session.
- RC1 delegate-recreation runtime count: needs Wayland; the static guard
  check is `xfail` until the extensions workstream lands the same-value
  guard in `services/Plugins.qml`.
- VM / hardware-dependent checks (real reboot, brightness/backlight,
  Bluetooth, package upgrade): live in `tests/vm/` and are NOT RUN here.
- Mutating horneroctl leaves are never executed by these suites; only
  their QML argv shape (`--yes` placement) is checked statically.
