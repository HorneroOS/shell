# Customisation

Principle (HorneroOS mission rules, section 6): when a value is debatable we ship the best default and let the
end user change it in Control Center. A hard-coded visual value needs a written justification. Every control shows
the factory value and a **Reset** button when the value differs from it.

## Surface sizes (Control Center)

| Size | Config key | Pane | Range | Default |
|------|-----------|------|-------|---------|
| Launcher item width / height | `launcher.sizes.itemWidth` / `itemHeight` | Launcher | 400-1000 / 32-80 | 640 / 44 |
| Launcher wallpaper tile | `launcher.sizes.wallpaperWidth` / `wallpaperHeight` | Launcher | 160-480 / 120-360 | 280 / 200 |
| Notification width / image | `notifs.sizes.width` / `image` | Notifications | 280-640 / 24-96 | 400 / 41 |
| Notification centre width | `sidebar.sizes.width` | Notifications | 320-720 | 430 |
| Toast width | `utilities.sizes.toastWidth` | Notifications | 280-640 | 430 |
| Power menu button | `session.sizes.button` | Session | 56-128 | 80 |
| Lock panel width | `lock.sizes.centerWidth` | Lock screen | 400-900 | 600 |

All are persisted in `shell.json` (serialised in `config/Config.qml`, mirrored in `config/shell.default.json`). The
shared row is `modules/controlcenter/components/SizeSlider.qml`: it clamps to the range, saves through `Config.save()`
and resets to the factory value. `tests/test_customisable_sizes.py` pins that each size has a bounded slider whose
default equals the factory file. Settings search finds them ("launcher size", "toast width", ...).

Already customisable elsewhere: rounding/spacing/padding/font/animation scales and transparency (Appearance), OSD slider
size and hide delay (OSD), border frame (Appearance), bar thickness and density (Bars). See the mission inventory for the
remaining backlog.

## Looks and glow (Appearance > Look)

A look is a named bundle of the scalar tokens: rounding, spacing and padding scale, font size scale, animation
duration scale and glow intensity. Applying one writes only those scalars, so each stays individually adjustable
(Scales, Fonts, Animations, Glow intensity), and colours remain a separate choice (Themes, Chromatic).

| Look | rounding | spacing | padding | font | motion | glow |
|------|---------:|--------:|--------:|-----:|-------:|-----:|
| Hornero (factory) | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| Cozy | 1.6 | 1.1 | 1.15 | 1.05 | 1.2 | 1.2 |

Cozy is opt-in; the factory default is unchanged. "Reset look to factory" writes the Hornero row.

`appearance.glow.intensity` (0 to 1.5, default 1) multiplies the alpha of glows that the experience mode and the
glow budget already allow (`Signal.glowIntensity`; consumers: `OnAirBar`, `ScopeTrace`). Gaming and Focus keep
glow off regardless. Plugin-kit glows do not follow it yet (tracked in HorneroOS/.github#32).
