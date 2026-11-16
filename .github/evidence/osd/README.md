# osd — Signal Bezel evidence (W4c)

- `before-*-virtual.png` — `main` at 5651dd2, captured from a nested
  Hyprland 0.57 instance on a headless 1920×1080 **virtual output** with an
  isolated config/state/DBus session (no personal data; app list pixelated).
- `after-*-offscreen.png` — this branch, rendered by an **offscreen
  software harness** (Qt `offscreen` platform, real shell services and
  theme roles, fixture desktop entries and fixture notifications). These are
  not desktop captures; the real-host 1920×1080 capture for this surface
  could not be taken while the shared host-display lock was held by a
  stale process (see the PR body).
- Themes: `night` = hornero-signal-night, `day` = hornero-signal-day,
  `hc` = Signal High Contrast (`appearance.highContrast`).
