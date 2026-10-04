# Shell integration contract

The Shell owns visual behavior and live session interactions. It uses the
installed `horneroctl` CLI for operating-system operations and shared file
contracts; package-owned configuration supplies defaults and read-only
catalogue data.

## Process boundaries

- Use Shell IPC for Control Center navigation and session actions.
- Use `horneroctl` for theme application, GTK settings, wallpaper state,
  capture, lock, hardware, package, and system operations.
- Invoke a platform utility directly only where that utility owns the platform
  capability and the Shell/CLI contract has tests for its arguments and errors.
- Never download wallpapers or themes implicitly. Missing optional catalogue
  media must remain an explicit unavailable state.

External process names and argument shapes are covered by
`tests/test_appearance_consistency.py`, `tests/test_controlcenter_panes.py`,
and `docs/IPC.md`.
