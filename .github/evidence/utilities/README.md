# utilities — Signal Bezel evidence (W4c, agent B)

- `after-*-offscreen-drawer.png` — this branch, offscreen Qt harness (real
  utilities `Content` and services, private session bus, isolated XDG dirs,
  no compositor). Not desktop captures. The Wi-Fi/Bluetooth/microphone
  states are this build host's real state; the recorder and idle inhibitor
  are idle. `Background.qml` and the delete modal need the drawers host
  and are covered by static tests only.
- Themes: `night`, `day`, `hc` (Signal High Contrast).
