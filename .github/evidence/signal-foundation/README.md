# Hornero Signal foundation — host evidence

Captured with `grim` on the maintainer's Arch Linux + Hyprland host
(single 1920x1080 output, scale 1) on 2026-11-16, running this branch's
shell from a worktree (`qs -p shell.qml`, worktree `Hornero.PluginKit` on
`QML_IMPORT_PATH`) against the user's real `shell.json` (migrated once,
then restored byte-identical). IBM Plex was installed user-level for the
run. Images are cropped to shell surfaces; layout is the user's Hornero
Left preset. Night is the factory default; Day was applied live by
atomically replacing `~/.local/state/hornero/signal/scheme.json`.

| File | Surface | SHA-256 |
| --- | --- | --- |
| `bar-left-day.png` | bar left day | `3b74fd20b40a3645…` |
| `bar-left-night.png` | bar left night | `20337c3591f3f5c8…` |
| `controlcenter-accessibility-night.png` | controlcenter accessibility night | `5ae5dfb29ba5c4cb…` |
| `controlcenter-appearance-night.png` | controlcenter appearance night | `f36cddde854e6614…` |
| `dashboard-day.png` | dashboard day | `f8a3d9324ee57639…` |
| `dashboard-night.png` | dashboard night | `ce68fe3466209c78…` |
| `launcher-night.png` | launcher night | `ce34301366464a68…` |
| `session-night.png` | session night | `18980df459e00bc4…` |
| `toasts-day.png` | toasts day | `525f968dbc719a65…` |
| `utilities-night.png` | utilities night | `8635a599ea12c26e…` |

Not captured: a bar hover popout (the pointer could not be driven on the
live session; warping the cursor does not open hover popouts).
