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
glow off regardless. Plugin-kit glows (`Theme.glowAlpha`) follow it too.

## More sizes (Control Center)

| Setting | Config key | Where | Range | Default |
|---------|-----------|-------|-------|---------|
| Launcher max items / wallpapers / drag | `launcher.maxShown` / `maxWallpapers` / `dragThreshold` | Launcher | 3-16 / 3-15 / 10-200 | 8 / 9 / 50 |
| Notifications per group, expand threshold | `notifs.groupPreviewNum` / `expandThreshold` | Notifications | 1-8 / 5-80 | 3 / 20 |
| Toasts on screen | `utilities.maxToasts` | Notifications | 1-8 | 4 |
| Bar popup widths | `bar.sizes.{trayMenuWidth,batteryWidth,networkWidth,kbLayoutWidth,windowPreviewSize}` | Bars > Popup sizes | see pane | 300/250/320/320/400 |
| Control Center window | `controlCenter.sizes.{heightMult,ratio}` | Appearance > Look | 0.5-0.95 / 1.2-2.4 | 0.7 / 16:9 |

Note: `dashboard.sizes.*` are not listed because nothing in the shell reads them today; exposing dead settings would
mislead, so they are left out until the dashboard consumes them.

## Text weight and motion style (Appearance > Look)

- `appearance.font.weight.shift` (-200..+200 in steps of 100, default 0) moves every text weight token
  (`Appearance.font.weight.regular|medium|strong`, 400/500/600 at the factory value). Shared StyledText and the
  call sites that used literal 500/600 now use the tokens; a test forbids new literals.
- `appearance.anim.curveStyle` = `smooth` (factory) | `snappy` (no overshoot) | `bouncy` (a little more give on
  spatial motion only). Opacity/colour never overshoot, and reduced motion still wins.
- The Cozy look uses the bouncy style; the Hornero look restores weight 0 and smooth.

## Customisation overview (Control Center > Customisation)

Lists every look, size and behaviour setting that differs from `config/shell.default.json`, with its default, an **Edit**
button (jumps to the pane/section), a per-item **Reset**, a search field, and **Reset all** (with confirmation).
Your data is never listed or reset: apps, paths, favourites, hidden apps, launcher actions, bars/layouts, chromatic
and per-surface transparency maps. The rules live in `services/customisation.js` (pure, tested with node).

### Look packs

Export turns the changed settings into a JSON text (`hornero/look-pack@1`, values keyed by dotted path); Import validates each
entry against the factory file (known customisation path, same type, number clamped to 0..10x the factory value) and
reports what it skipped. User data and unknown keys are rejected. Logic: `exportPack` / `validatePack` in
`services/customisation.js`. A file-based `horneroctl config export|import` can reuse the same format later.
