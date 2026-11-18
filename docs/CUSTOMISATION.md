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

## How changes apply

Every setting applies the moment it is chosen. There is no Apply button anywhere in the Control Center; risky or
slow changes also show an "Applied · Undo" strip for `controlCenter.undoSeconds`. The full policy, the shared Undo
service and a pane-by-pane table are in `docs/CONTROL-CENTER-APPLY.md`.

## More sizes (Control Center)

| Setting | Config key | Where | Range | Default |
|---------|-----------|-------|-------|---------|
| Launcher max items / wallpapers / drag | `launcher.maxShown` / `maxWallpapers` / `dragThreshold` | Launcher | 3-16 / 3-15 / 10-200 | 8 / 9 / 50 |
| Notifications per group, expand threshold | `notifs.groupPreviewNum` / `expandThreshold` | Notifications | 1-8 / 5-80 | 3 / 20 |
| Toasts on screen | `utilities.maxToasts` | Notifications | 1-8 | 4 |
| Bar popup widths | `bar.sizes.{trayMenuWidth,batteryWidth,networkWidth,kbLayoutWidth,windowPreviewSize}` | Bars > Popup sizes | see pane | 300/250/320/320/400 |
| Control Center window | `controlCenter.sizes.{heightMult,ratio}` | Appearance > Look | 0.5-0.95 / 1.2-2.4 | 0.7 / 16:9 |
| How long Undo stays after a change | `controlCenter.undoSeconds` | Appearance > Look | 3-60 s | 10 |

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
button (jumps to the pane/section), a per-item **Reset**, a search field, and **Reset all**. Resets apply at once and offer Undo; there is no confirmation step (see
`docs/CONTROL-CENTER-APPLY.md`).
Your data is never listed or reset: apps, paths, favourites, hidden apps, launcher actions, bars/layouts, chromatic
and per-surface transparency maps. The rules live in `services/customisation.js` (pure, tested with node).

### Look packs

Export turns the changed settings into a JSON text (`hornero/look-pack@1`, values keyed by dotted path); Import validates each
entry against the factory file (known customisation path, same type, number clamped to 0..10x the factory value) and
reports what it skipped. User data and unknown keys are rejected. Logic: `exportPack` / `validatePack` in
`services/customisation.js`. A file-based `horneroctl config export|import` can reuse the same format later.

## Atmosphere (Appearance > Atmosphere)

The atmosphere is the warm layer over the Signal surfaces: a lamp wash, a soft inner highlight, a gentle vignette,
film grain and optional scanlines, plus the hornero mascot and the microcopy voice (design language: HorneroOS/docs
`development/signal-visual-language.md` section 17). It is opt-out and every value is a setting
(`appearance.atmosphere.*`, validated, clamped to the slider range, with a reset):

| Key | Range | Factory | Control |
|-----|-------|--------:|---------|
| `enabled` | on/off | on | Atmosphere switch (turns the whole layer off) |
| `lamp` | 0 to 1.5 | 0.8 | Lamp light |
| `warmth` | 0 to 1 | 0.2 | Lamp tint, amber (palette `glow`) to rose (`blush`) |
| `innerLight` | 0 to 1.5 | 0.8 | Soft inner highlight along the top edge |
| `vignette` | 0 to 1 | 0.4 | Vignette |
| `grain` | 0 to 1 | 0.3 | Film grain |
| `scanlines` | 0 to 1 | 0 | Scanlines (off by default) |
| `plateTracking` | 0 to 0.3 em | 0.14 | Plate label tracking (`Plate` component, enums only) |
| `mascot` | on/off | on | Hornero mascot in empty states, greetings and the session menu |
| `tone` | `cozy` or `plain` | cozy | Microcopy voice |

Follow-ups (Bezel Calido, docs#131): lamp, vignette, grain and scanlines also drop in the power-saver profile; changing
mode or the on/off switch fades the layer over 480 ms (instant under reduced motion and low power); the Cozy look now
scales rounding by 1.2 so effective radii stay inside `small x 2` (no pill drift); the atmosphere is never attached to
bars, so Cockpit Clear gets no tint; `Atmosphere.alertText` (also `Tooltip.alertColor`) is the legible alert pairing on
`lifted` where a palette such as Dusk puts plain `alert` under 4.5:1.

Guardrails that no setting overrides: the layer is hidden in High Contrast and in the Focus, Gaming and Studio modes
(a stable, colour-neutral canvas); day themes keep a softer lamp and drop vignette and scanlines; the lamp takes one
lease from the shared glow budget (`Experience.acquireGlow`, reserving a slot for the on-air bar and scope traces) and is
left out when the budget is spent; reduced motion stops the mascot's blink and the empty-state settle. Every alpha has a
hard ceiling in `services/atmosphere.js`, so a hand-edited value cannot exceed the language. Grain and scanlines sit
under the content (text stays crisp); lamp, highlight and vignette are a veil of at most a few percent.

Two accent chips, `Atmosphere.lamp` and `Atmosphere.blush`, are derived from the active palette (so custom and
Chromatic palettes get them too) and are pulled toward `ink` until they pass 4.5:1 on all six surfaces. Look > Cozy
sets the atmosphere knobs too and softens corners by 1.2 (lamp 1.2, tint 0.45, highlight 1.1, vignette 0.5, grain 0.4); "Reset look to factory"
restores the factory row. The on/off switch is never changed by a look.

Surfaces carrying the layer: launcher, dashboard, notification cards (inner highlight only), OSD, session menu, lock
screen, Welcome, and the Control Center navigation rail and title bar. Empty states with the mascot: launcher (no
results), sidebar and lock notification docks; greetings: dashboard station card and lock screen; session menu footer.
Typography: `StyledText.tabular` turns on fixed-width figures (readouts, clocks) and display clocks are set a hair tighter.

## Idle and battery thresholds (Power)

`general.idle.timeouts` (lock 3 min, screen off 5 min, suspend 10 min) and `general.battery` warning levels
(20 / 10 / 5 %) and hibernate level (3 %) are editable under Power > Idle and battery, with Reset per row. Rows
are matched by action (lock, dpms off, suspend), so hand-edited or reordered lists keep working; a removed action
leaves its row inert.

## Glow budget (Appearance > Look)

`appearance.glow.limit` (1 to 6, default 3) is how many glowing items may show at once (`Experience.glowLimit`); the
visual language default is three. Mode rules (no glow in Focus or Gaming, dark themes only) still decide whether any
glow shows. `appearance.anim.mediaGifSpeedAdjustment` and `sessionGifSpeed` are not offered: nothing reads them today.

## Wallpaper fit (Appearance > Background)

`background.wallpaperFit`: `crop` (factory, fill and crop), `fit` (whole image), `stretch`, `center`. Applies to still,
animated and video wallpapers (video has no pad mode, so centre plays as fit).

## Placement (Launcher, OSD)

`launcher.align` (left | centre | right along the bottom edge) and `osd.align` (top | centre | bottom along the right
edge); both default to centre. The panels keep their edge (hover regions and slide animations depend on it), only
their position along it changes. Notification corner/edge is not offered yet: the popups, toasts and the notification
centre share the top-right anchor with the sidebar. Needs a QA VM check for the concave corner decoration when a
launcher is aligned left or right.

## One range table and the `// fixed:` lint

- `config/ranges.json` lists the min/max/step/default of every `SizeSlider` (generated by `scripts/gen_ranges.py`;
  `tests/test_customisation_ranges.py` fails when it is stale and when a default falls outside its range). Look-pack
  import clamps to these ranges; horneroctl falls back to 0..10x the factory value until it reads the table.
- Lint: a new numeric `radius:` or `font.pointSize:` literal in `components/` or `modules/` fails the test unless it is a
  token (`Appearance.rounding.*`, `Appearance.font.size.*`) or the line ends in `// fixed: <reason>`. Only growth over
  `tests/fixed_baseline.json` fails, so existing code is unaffected; lower the baseline when converting literals.

their position along it changes. Needs a QA VM check for the concave corner decoration when a launcher is aligned left
or right.

`notifs.align` (left | centre | right along the top edge, default right) moves the popup stack only. The popup tray was
the shared top-right anchor of the notification centre (sidebar hangs below it, and the input mask follows its
geometry); the tray now anchors per `align` and only widens to the sidebar when it is on the right, so the centre stays
on the right edge. Left placement also flips the dismiss slide. Bottom corners are not offered on purpose: utilities,
toasts and the launcher own the bottom edge. Centre shares the edge with the dashboard, which draws above popups while
it is open.
