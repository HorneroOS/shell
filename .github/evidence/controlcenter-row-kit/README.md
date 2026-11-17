# Control Center row kit sweep, Power, Updates, Wi-Fi settings — evidence (agent F)

Offscreen software renders (Qt `offscreen`, real shell services and theme
roles, isolated XDG tree; not desktop captures, not QA-VM). `ClippingRectangle`
is shimmed to `Rectangle` in a scratch copy because it does not grab
offscreen. Themes: `night`, `day`, `hc` (Signal High Contrast).

- `power-*`, `updates-*` — the real panes with `horneroctl` stubbed to answer
  "not available", so every readout shows its honest "unavailable" state.
- `wifi-settings-*` — the real `WirelessSettings` (framed `SectionContainer`,
  eyebrow `SectionHeader`, mono `PropertyRow` values). NetworkManager is not
  reachable from the harness, so signal, security and frequency print
  "unavailable" instead of "N/A".
- The System pane (instrument-style resources with segmented meters) was
  verified locally but is not committed: it reads the host's `/proc` and
  prints the machine's real CPU and GPU model names.
