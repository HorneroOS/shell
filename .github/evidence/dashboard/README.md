# dashboard — Signal Bezel evidence (W4c, agent B)

- `before-night-offscreen-home.png` — `main` at 02cc16b, home tab
  (`Dash.qml` only, rendered by the same offscreen harness; the old
  `ClippingRectangle` tab shell does not render in software capture).
- `after-{night,day,hc}-offscreen-*.png` — this branch, rendered by an
  **offscreen** Qt harness (Qt `offscreen` platform + llvmpipe, the real
  shell services and Signal theme roles, isolated XDG dirs, a private session bus and no
  compositor). These are not desktop captures and not QA-VM captures.
  Telemetry in the captures is this build host's real CPU/memory/disk/net
  readings; no player, weather location or compositor is attached, so
  those modules show their honest empty states.
- Themes: `night` = hornero-signal-night, `day` = hornero-signal-day,
  `hc` = Signal High Contrast (`appearance.highContrast`).
- Tabs captured: home, media, performance, weather. Workspaces and
  extensions need a compositor / plugin host and are covered by tests.
