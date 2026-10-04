# AGENTS.md — HorneroOS/shell contributor rules

## QML / Qt

- QML only; no new C++ unless QML provably cannot do it (then extend
  `plugin/`, keep the QML API in `Hornero` modules).
- Import discipline: `qs.config`, `qs.services`, `qs.utils`,
  `qs.components*` for in-repo code; `Quickshell`, `Quickshell.Io`,
  `QtQuick` (+Layouts) from the platform. No relative imports outside
  sibling dirs.
- Singletons: `pragma Singleton` + registration-free `qs.*` naming as in
  existing files. Services never construct UI; modules never own system
  state — state lives in `services/`, knobs in `config/`.
- `qmllint` must pass on every changed `.qml` file.

## IPC / Process

- New `IpcHandler` targets/functions must be documented in `docs/IPC.md`
  **and** covered in `tests/test_ipc_mapping.py` in the same commit.
- Shell integration uses the installed `horneroctl` command contract.
  Keep platform-specific process calls behind tested services; QML must not
  call appearance scripts directly (enforced by
  `tests/test_appearance_consistency.py`).
- Outbound commands are contracts: keep arg order stable, quote paths,
  never pass unsanitized user input to `sh -c`.

## Paths / coupling

- No personal paths, usernames, hostnames, SSIDs, tokens, or emails in
  code, tests, or docs. Resolve user locations via `utils/Paths.qml`
  (env → XDG → `$HOME`); add new knobs there, not inline.
- No chezmoi/template markers (`{{ … }}`) anywhere
  (`tests/test_static_scans.py`).
- `presets/*.json` schema: `_name`, `_description`, bar entries with
  `id`/`enabled`, sizes/status/scrollActions, v2 `bars` set
  (`docs/LAYOUTS.md`) — keep `tests/test_shell_layout.py` green
  (15 presets).

## Commits / hygiene

- Small coherent commits (`chore:`/`feat:`/`refactor:`/`test:`/`docs:`)
  with provenance footers for imports.
- Run before pushing: `cmake -S . -B build && cmake --build build`,
  `python3 -m pytest tests/ -q`, `pre-commit run --all-files`,
  `./scripts/check_personal_data.sh`, `./scripts/check_forbidden_paths.sh`.
- Dual license: docs/scaffold MIT, runtime GPL-3.0 — never strip headers,
  never relicense imported files.
