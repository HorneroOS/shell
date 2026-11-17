# sidebar — Signal Bezel evidence (W4c, agent B)

- `after-*-offscreen-notifications.png` — this branch, rendered by an
  **offscreen** Qt harness: the real sidebar `Content`/`NotifDock` and
  notification service, with four fixture notifications sent through a
  private session bus (`notify-send`), isolated XDG dirs, no compositor.
  They are not desktop captures. The sheet outline is drawn by the harness;
  `Background.qml` (the attached path) needs the drawers host and is covered
  by static tests only.
- Themes: `night` = hornero-signal-night, `day` = hornero-signal-day,
  `hc` = Signal High Contrast.
