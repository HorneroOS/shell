# Native appearance — Hornero Signal

The shell's appearance is **Hornero Signal**
([RFC 0001](https://github.com/HorneroOS/docs/blob/main/development/rfc-0001-hornero-signal.md),
tracked in [HorneroOS/.github#28](https://github.com/HorneroOS/.github/issues/28)).
This page describes how the shell implements it: colour roles, typography,
glyphs, motion, geometry, and the native layers that apply GTK settings.

A theme is a complete table of Signal roles. With a curated theme,
changing the wallpaper changes only the wallpaper. The optional
**Hornero Chromatic** theme (`hornero-chromatic`,
[RFC 0002](https://github.com/HorneroOS/docs/blob/main/development/rfc-0002-hornero-chromatic.md)) builds that table from the wallpaper, an image or a
chosen colour; it is specified but not implemented yet (see
[Hornero Chromatic](#hornero-chromatic-planned) below).

## Colour roles — `services/Signal.qml`

`Signal.palette.<role>` is the only colour API for shell surfaces. The roles
are exactly RFC 0001 §3.1:

| Group | Roles |
|---|---|
| Surfaces (back to front) | `ground`, `sunken`, `base`, `panel`, `raised`, `lifted` |
| Ink | `ink`, `inkMuted`, `inkFaint` (decorative only) |
| Rules | `rule` (hairlines inside a surface), `ruleStrong` (control boundaries, 3:1) |
| Accents | `signal`/`onSignal`, `signalWell`/`onSignalWell` (amber: primary, live) |
| | `cue`/`onCue`, `cueWell`/`onCueWell` (celeste: focus, selection, information) |
| | `phosphor`/`onPhosphor`, `phosphorWell`/`onPhosphorWell` (positive, connected) |
| | `alert`/`onAlert`, `alertWell`/`onAlertWell` (destructive, error) |
| Inverse | `inverse`, `onInverse`, `inverseSignal` |
| Other | `focus` (keyboard ring), `scrim`, `shadow`, `term0`…`term15` |
| Optional | `glow` (luminous accent; falls back to `signal` when a theme omits it) |

Other members:

- `Signal.tPalette.<role>` — translucent variants used when transparency is
  enabled (surface roles become see-through, content roles stay opaque).
- `Signal.layer(colour, depth)`, `Signal.surface(colour, element)`,
  `Signal.elementAlpha(element)`, `Signal.transparency` — the translucency
  helpers (`appearance.transparency` in `shell.json`).
- `Signal.on(colour)` — readable ink for data-driven fills only; use the
  paired `on*` role whenever one exists.
- `Signal.light`, `Signal.themeId`, `Signal.themeStateReady`,
  `Signal.roles`, `Signal.builtInThemes`, `Signal.isBuiltInTheme(id)`,
  `Signal.isCompletePalette(palette)`, `Signal.applyScheme(scheme)`,
  `Signal.persistScheme(scheme)`, `Signal.schemePath`.

High contrast (`appearance.highContrast`) swaps in the
`hornero-signal-contrast` table and disables translucency without changing
the stored theme identity.

### Built-in themes

| Id | Mode | Notes |
|---|---|---|
| `hornero-signal-night` | dark | Factory default: graphite panels, phosphor-cream ink |
| `hornero-signal-day` | light | Technical-drawing paper with ink-black text |
| `hornero-signal-contrast` | dark | Black ground, white ink, boosted accents |

The hex values are RFC 0001 §3.2 (with amendment 2). `tests/test_contrast_aa.py`
and `tests/test_high_contrast_mode.py` check WCAG AA: `ink`/`inkMuted` and
every accent used as text reach 4.5:1 on every surface (including `sunken`
wells and `lifted` tooltips), every paired `on*` role reaches 4.5:1 on its
fill, and `ruleStrong`/`focus` reach 3:1 on every surface.

### Live scheme contract

```text
${XDG_STATE_HOME:-~/.local/state}/hornero/signal/scheme.json
{"schemaVersion": 2, "id": "…", "mode": "dark"|"light",
 "palette": {"<role>": "#RRGGBB", …}, "terminal": ["#RRGGBB", × 16]}
```

- `horneroctl appearance theme apply <id>` writes it atomically for catalogue
  themes (and, once RFC 0002 ships, horneroctl writes it for the
  `hornero-chromatic` theme); the shell writes it for built-ins (`Signal.persistScheme`, an
  atomic `mv`) and on first run when the file is missing.
- `Signal` watches the file and applies any complete schema-v2 scheme.
  Incomplete or legacy (schema 1, M3) files are ignored and the configured
  built-in is shown instead.
- The `signal` IPC target exposes `reload()`, `mode()` and `theme()`
  (`docs/IPC.md`).

### Theme catalogue

`services/ThemeCatalogue.qml` lists the three built-ins first, then every
catalogue theme from `horneroctl appearance theme list --full` that carries a
complete schema-v2 `palette`. Theme packs that only define M3 seeds cannot
render under Signal and are not offered.

### One-shot migration

`Config.migrateLegacyAppearance()` (`config/Config.qml`) runs when
`shell.json` loads and rewrites removed values once, then saves:

- `appearance.theme`: `hornero-dark` → `hornero-signal-night`,
  `hornero-light` → `hornero-signal-day`, `hornero-199x` → `hornero-signal-night`.
- `appearance.font.family`: `Rubik` → `IBM Plex Sans`,
  `CaskaydiaCove NF` → `IBM Plex Mono`; the removed `material`/`clock`
  keys disappear on save (`display` replaces `clock`).
- Icon names stored in `session.icons`, `general.battery.warnLevels[].icon`
  and `launcher.actions[].icon` that are not Hornero Glyphs fall back to the
  shipped default for that slot.
- Launcher actions: the removed Scheme/Variant actions are dropped and the
  Light/Dark actions now apply `hornero-signal-day`/`hornero-signal-night`.
- The persisted motion curve table is no longer serialized and disappears
  on the next save.

## Hornero Chromatic

[RFC 0002](https://github.com/HorneroOS/docs/blob/main/development/rfc-0002-hornero-chromatic.md) adds dynamic colour as an option next to the curated
themes. The engine is tracked in
[shell#525](https://github.com/HorneroOS/shell/issues/525) (engine) and
[shell#526](https://github.com/HorneroOS/shell/issues/526) (UI and
PluginKit). The Signal side below (preview, transitions, floors, Clear
ink, preferences) is implemented in this repository.

- One native engine, written once in C++: `libs/chromatic/` (Qt Core/Gui
  only), used in-process by the QML module `Hornero.Chromatic` for previews
  and by the `hornero-chromatic` helper (`/usr/lib/hornero`) that horneroctl
  runs for every apply. No Python and no external colour library.
- Output is the Signal role set above, `glow` and `term0`…`term15`, plus
  optional additive `chromatic`, `minSurfaceAlpha` and `clearInk` blocks in
  the live scheme.
- The shell previews in memory only (`Signal.beginPreview` /
  `cancelPreview`); cancelling writes nothing. Apply always goes
  through horneroctl's Chromatic apply verb (RFC 0002 §10); horneroctl stays
  the only writer of the live scheme for Chromatic.
- `Signal` API: `beginPreview(scheme)` validates a complete schema-v2 palette
  and swaps it in memory (the first call snapshots the live palette,
  identity and optional blocks); `commitPreview()` ends the preview and
  keeps the palette until the applied scheme arrives through the live file;
  `cancelPreview()` restores the snapshot. A live-file change that arrives
  during a preview becomes the restore point and does not touch the screen.
  `previewing`, `chromatic` (read-only status, never a path),
  `minSurfaceAlpha`, `clearInk` and `transitionMode` are readable.
- Palette changes (live-file reload, preview, cancel) interpolate in OKLab
  (`services/chromatic.js`): at most 12 steps, one 20 ms tick each, 240 ms
  at most. The final step assigns the exact target. They are instant under
  reduced motion, the gaming experience mode, high contrast or
  `appearance.chromatic.transition = "instant"`. A step's binding work is
  budgeted at 2 ms (measured by `tests/test_chromatic_ui_transition.py`).
- `minSurfaceAlpha` raises, never lowers, the translucency of `Signal.layer`
  and `Signal.surface` per surface role (`bar` follows `base`; every other
  element follows `panel`). Opaque themes and High Contrast are unaffected.
- `ClearInk.sets` takes the polarity ink sets from the scheme's `clearInk`
  block (per key fallback to the fixed Night/Day sets). It never adds a fill.
- Preferences live in `appearance.chromatic` (see
  `config/AppearanceConfig.qml` and `config/shell.default.json`): `source`,
  `seeds`, `variant`, `mode`, `contrast`, `surfaceDepth`, `chroma`,
  `hueShift`, `follow` (`off`/`auto`/`ask`), `perMode`, `fallback`,
  `transition`. A missing block takes these defaults.
- `appearance.highContrast` keeps showing the curated
  `hornero-signal-contrast` table. Cockpit Clear bars stay at zero opacity;
  Chromatic only changes their foreground ink.

## Typography — `config/AppearanceConfig.qml`

| `Appearance.font.family.*` | Font | Use |
|---|---|---|
| `sans` | IBM Plex Sans | UI text |
| `mono` | IBM Plex Mono | Readouts, numerals, eyebrows, code |
| `display` | IBM Plex Sans Condensed | Clock, lock, large headings |

Sizes (`Appearance.font.size.*`, points at scale 1): `small 11`,
`smaller 12`, `normal 13`, `larger 15`, `large 18`, `extraLarge 28`,
`display 56`. Package dependency: `ttf-ibm-plex` (Arch `extra`, OFL-1.1;
Nix `ibm-plex`).

## Glyphs — Hornero Glyphs

`Glyph { name: "wifi"; color: …; size: … }` (`components/Glyph.qml`)
renders one glyph from `assets/fonts/hornero-glyphs.ttf`, a curated subset of
Tabler Icons (outline, MIT). `font.pointSize` also works; there are no fill
or grade axes. `utils/Glyphs.qml` loads the font and resolves names
(`Glyphs.glyph(name)`, `Glyphs.has(name)`, `Glyphs.family`, `Glyphs.names`);
an unknown name renders nothing and logs one warning.

The glyph set is listed in `assets/fonts/hornero-glyphs.names`. To add a
glyph, add its Tabler name there and run `python3 scripts/build-glyphs.py`
(pinned `@tabler/icons-webfont` release, SHA-256 verified), which rewrites the
font, `utils/GlyphMap.js` and `assets/fonts/LICENSE.tabler-icons`.
`tests/test_glyphs.py` fails when code uses a name that is not in the set.

## Motion — `Appearance.anim`

| Curve (`Appearance.anim.curves.*`) | Bezier | Use |
|---|---|---|
| `standard` | 0.2, 0, 0, 1 | State changes |
| `enter` | 0.05, 0.7, 0.1, 1 | Things appearing |
| `exit` | 0.3, 0, 1, 1 | Things leaving |
| `sweep` | 0.65, 0, 0.35, 1 | Reveal wipes, page transitions |
| `settle` | 0.32, 1.24, 0.42, 1 | Small overshoot, spatial motion only |
| `settleFast` | 0.34, 1.3, 0.5, 1 | Quick controls, chips |

Durations (`Appearance.anim.durations.*`, ms at scale 1): `quick 90`,
`short 160`, `medium 240`, `long 360`, `scan 480`, `settleFast 220`,
`settle 320`, plus `fade` (≤ 90 ms opacity cross-fade). `durations.scale`
is the user's animation-speed setting.

Reduced motion (`appearance.reducedMotion`, the Accessibility pane switch,
or the system preference `org.gnome.desktop.interface enable-animations`
read by `config/SystemMotion.qml`) sets `Appearance.anim.reduced` and every
duration except `fade` to 0. PluginKit `Theme.reducedMotion` follows it.

## Geometry — `Appearance.rounding/spacing/padding`

4 px grid (RFC 0001 §3.5). Rounding: `small 3`, `normal 5`, `large 8`,
`full` only for genuinely circular elements. Spacing: `small 4`,
`smaller 8`, `normal 12`, `larger 16`, `large 24`. Padding: `small 4`,
`smaller 6`, `normal 8`, `larger 12`, `large 16`. Each has a user `scale`.

## Theme application — `services/ThemePipeline.qml`

- Built-in themes apply natively: `Signal.applyScheme` + `persistScheme`,
  optional wallpaper pointer write, Hyprland/hyprlock regeneration, then the
  GTK light/dark preference (or the full GTK recipe when the shared registry
  knows the id).
- Catalogue themes go through `horneroctl appearance theme apply <id>`, which
  owns verification and persisted state and writes the live scheme (or calls
  back through the `appearance.applyTheme` IPC path).
- `setWallpaper` only writes the wallpaper pointer.

### GtkSettings (`services/GtkSettings.qml`)

Applies GTK themes, icon themes, and colour-scheme policy through
`gsettings`, then mirrors successful live changes through
`horneroctl appearance gtk` so GTK's persistent settings files stay in sync.
If gsettings is unavailable or fails, the Hornero CLI adapter applies both
live and persistent state directly.

| Policy | `org.gnome.desktop.interface color-scheme` |
|---|---|
| `prefer-light` | `prefer-light` |
| `prefer-dark` | `prefer-dark` |
| `default` | `default` |
| `follow` (or empty) | `prefer-dark` when dark mode, else `prefer-light` |

## External CLI surface (all horneroctl)

| Call site | Command |
|---|---|
| `ThemePipeline` catalogue apply | `horneroctl appearance theme apply <id> [--wallpaper …] --yes` |
| `ThemePipeline` side effects | `horneroctl appearance hyprland --yes`, `horneroctl appearance hyprlock --yes`, `horneroctl apps switcher apply-theme-pack <id> --yes` |
| `GtkSettings` full mode with a registry id | `horneroctl appearance gtk theme …` |
| `GtkThemeSection` / `IconThemeSection` | `horneroctl appearance gtk list/icons` |
| `AppearancePane` live queries (fallback) | `horneroctl appearance gtk current*` |
| `ThemeCatalogue` | `horneroctl appearance theme list --full` |
| `Wallpapers.resolveProc` | `horneroctl wallpaper current` |
| `QuickToggles` / `SystemPane` night toggle | `horneroctl appearance night-mode toggle --yes` |

## Contracts and checks

- QML never invokes appearance helper scripts directly
  (`tests/test_appearance_consistency.py`, `scripts/check_forbidden_paths.sh`).
- `tests/test_signal_contract.py` fails on Material-era names (`m3` roles,
  the Material icon component and font, the M3 palette type, the
  wallpaper-synthesis library) anywhere in first-party code, packaging and
  docs except `docs/PROVENANCE.md` and `NOTICE`.
