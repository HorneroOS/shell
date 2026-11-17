# Control Center settings panes on channel panels — evidence (agent F)

Offscreen software renders (Qt `offscreen`, real shell services and theme
roles, isolated XDG tree; not desktop captures, not QA-VM). `ClippingRectangle`
is shimmed to `Rectangle` in a scratch copy because it does not grab
offscreen. Themes: `night`, `day`, `hc` (Signal High Contrast).

Notifications, On-screen display, Accessibility, Lock screen and Terminal as
real panes. The harness has no `horneroctl`, so the Terminal pane lists its
terminals as "Not installed" and shows the stub's "not available" message;
setting values (toggles, sliders) are the shell's own defaults, because no
`shell.json` exists in the isolated config dir.
