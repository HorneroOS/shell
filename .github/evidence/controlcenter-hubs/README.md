# Control Center hubs, layout presets, rocker and wells — evidence (W4c, agent C)

All images are **offscreen software renders** (Qt `offscreen` platform, real
shell services and theme roles, isolated XDG tree; not desktop captures).
They are not QA-VM or host evidence.

- `layout-presets-*` — the real `PresetGrid` fed by `horneroctl shell preset
  list --full`; Cockpit shown as the active card (`signalWell` fill, `signal`
  border, check badge). Glyphs come from the shell's own preset table.
- `studio-hub-*`, `gaming-hub-*` — the real `PaneHeader` (channel eyebrow
  from the registry) and `DoctorBoard` fed by the real
  `horneroctl --json studio|gaming doctor`, run with isolated XDG. Chrome of
  the Control Center (split-pane clipping) is not part of the render.
- `rocker-and-wells-*` — `StyledSwitch` rocker (on, off, disabled, focused)
  and `StyledInputField` sunken wells.
- Themes: `night` = hornero-signal-night, `day` = hornero-signal-day,
  `hc` = Signal High Contrast (`appearance.highContrast`).
