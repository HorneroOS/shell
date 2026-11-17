# welcome — Signal Bezel evidence (W4c, agent B)

- `after-*-offscreen-{start,shortcuts}.png` — this branch, rendered by an
  **offscreen** Qt harness (offscreen platform + llvmpipe, the real Welcome
  pages and shell services/Signal roles, private session bus, isolated XDG
  dirs). The page content is drawn on a `base` panel: the window chrome
  (`FloatingWindow` header, nav rail, footer) needs a compositor and is
  covered by tests only, not by these captures.
- The edition panel shows live service state on the build host: the
  Studio profile reads "Checked on first use" because the probe has not
  run, and Gaming compositor tuning reads "Not available" because no
  compositor is attached. The shortcuts page is empty because the isolated
  profile has no `shortcuts.json`; it says so.
- Themes: `night` = hornero-signal-night, `day` = hornero-signal-day,
  `hc` = Signal High Contrast.
