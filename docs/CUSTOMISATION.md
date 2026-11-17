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
