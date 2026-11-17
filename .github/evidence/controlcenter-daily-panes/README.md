# Control Center daily panes (Audio, Displays, Input) — evidence (agent F)

Offscreen software renders (Qt `offscreen`, real shell services and theme
roles; not desktop captures, not QA-VM). `ClippingRectangle` is shimmed to
`Rectangle` in a scratch copy because it does not grab offscreen. Themes:
`night` = hornero-signal-night, `day` = hornero-signal-day, `hc` = Signal High
Contrast.

- `audio-*` — the real `AudioPane` reading a **real PipeWire graph**: an
  isolated `pipewire` + `wireplumber` started in a scratch runtime dir (no
  ALSA/Bluetooth/V4L monitors, never the host daemon) holding two null sinks,
  two null sources and two `pw-cat` playback streams named Firefox and
  Spotify. Volumes were set with `wpctl` (72 %, 45 %, 30 %, 88 %). Device names
  end in "(fixture)" because they are synthetic nodes; every number and name
  on screen is read back from PipeWire through the `Audio` service. The meter
  is the node's set level, not a live signal peak.
- `displays-*` — the real `DisplaysPane`. The only output is the offscreen
  platform screen (800x800, no name, no model, no Hyprland), so refresh and
  scale correctly print an em dash and Brightness / Compositor print
  "unavailable". `horneroctl` was stubbed to answer "not available".
- `input-*` — the real `InputPane` in the same "horneroctl not available"
  state; the pointer panel then says it is unavailable and shows no controls.
