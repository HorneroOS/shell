# Layouts and bar configuration

Hornero Shell layouts describe desktop chrome: one or more bars, each attached
to a distinct screen edge and divided into `start`, `center`, and `end` groups.
The runtime contract is `bar.bars`; presets and factory defaults use the same
schema.

## Bar specification

```json
{
  "edge": "top",
  "style": "inset",
  "margin": 8,
  "thickness": 40,
  "reserve": true,
  "density": "values",
  "backdrop": "solid",
  "groups": {
    "start": [{"id": "logo", "enabled": true}],
    "center": [{"id": "clock", "enabled": true}],
    "end": [{"id": "tray", "enabled": true}]
  }
}
```

Each bar requires an edge, style, and all three groups. Edges are `top`,
`bottom`, `left`, and `right`; a layout may use each at most once. A malformed
bar is ignored. Per-screen bar sets override the global set when present.

| Field | Values | Default |
| --- | --- | --- |
| `style` | `attached`, `inset`, `floating`, `islands`, `dock` | `attached` |
| `margin` | 0–256 px | 8 |
| `thickness` | 16–256 px | `bar.sizes.innerWidth` |
| `reserve` | boolean | true for strips and docks, false for floating styles |
| `density` | `values`, `glyphs` | `values` |
| `backdrop` | `solid`, `clear` | `solid` |

`attached` fills its edge, `inset` leaves a deliberate margin, `floating`
forms one pill, `islands` separates non-empty groups, and `dock` is a floating
strip that reserves workspace. `reserve` can explicitly override the style
rule. A clear backdrop removes the bar slab while preserving geometry and
reservation; the edge scrim maintains contrast, and popouts remain opaque cards.

Horizontal bars compact wide controls on narrower screens. If the center
group cannot fit, it hides rather than overlapping the side groups. Vertical
bars reserve their edge and horizontal bars remain on their own edge so mixed
topologies do not collide. `glyphs` density removes numeric values from
resource, battery, and weather controls while retaining their state icons.

## Components and actions

Groups contain `{ "id", "enabled", "options"? }` entries. The component ID
must be registered in `modules/bar/Bar.qml`; spacer entries are not used because
the three groups provide the layout structure directly.

`options` are component-specific. Examples include `clock.showDate`,
`audioSlider.showValue`, `brightnessSlider.showValue`,
`workspaces.style` (`pills` or `labels`), and `media.maxWidth`.

Workspace indicators are fixed rectangular cells (signal-visual-language §5),
never pills. Every state differs in at least two cues, so colour is never the
only signal:

| State | Numeral | Fill | Mark |
| --- | --- | --- | --- |
| Empty | `inkMuted` | none | none |
| Occupied | `inkMuted` | none | 4 x 2 px tick, away from the content |
| Active | `ink` | `raised` | 2 px `signal` on-air bar on the content-facing edge |
| Visible on another monitor | `ink` | none | 1 px `ruleStrong` on the content-facing edge |
| Urgent | `alert` | none | `alert` tick and bar until the workspace is visited |

Set `workspaces.style` to `labels` for an always-labelled workspace row.

Bar actions reference IDs in `services/ShellActions.qml`, never shell command
strings. Current actions include launcher, layout picker, dashboard, session,
settings, and screenshot. Unknown actions are skipped with a warning.

## Shipped presets

The installed catalogue contains 14 presets (Signal Bezel audit,
signal-visual-language §14). It includes Hornero Left/Right (inspired by
Caelestia's layout, preserved with attribution), Cockpit (36 px inset top
rail, 30 px attached bottom strip) and Cockpit Clear (same anatomy, no bar
backdrop at all — adaptive per-region ink only), Horizon, Islands, Minimal
Float (formerly Cozy Minimal), Dock Bottom, Classic Top/Bottom, Minimal
Top/Left, Studio, and Gaming. **Cockpit is the factory default**
(`config/shell.default.json`, Experience profiles, `horneroctl` reset);
Hornero Left/Right stay supported presets. Floating Island and Productivity were removed:
their compositions duplicated Minimal Float and Minimal Top, and presets are
applied by copying their bars into the user config, so existing desktops
keep working unchanged — only the picker catalogue shrinks. A persisted
Experience `layout.preset` naming a removed preset is migrated once
(Floating Island to Minimal Float, Productivity to Minimal Top) by
`services/experience.js`. Every preset is
an explicit multi-bar specification and is validated by
`tests/test_shell_layout.py`.

`horneroctl shell preset list --full` reports display metadata and topology for
the Layout Picker. `horneroctl shell preset apply <name> --yes` applies a
preset to the user-owned Shell settings file; installed system presets are
read-only and are never changed.

## Cockpit Clear

`backdrop: "clear"` bars have a genuinely absent background (RFC 0001 §5.1):
no fill, tint, slab, blur, edge scrim or backdrop shadow, in every mode
including High Contrast. Legibility comes only from the foreground:

- **Adaptive ink.** `components/clearink/ClearInkField.qml` draws the
  wallpaper once (on wallpaper or screen change, never per frame) into a
  192-column luminance grid. Each bar entry owns a `ClearInkTone`: the
  mean and deviation of the wallpaper under it (padded 2 px) pick the
  polarity with the larger contrast, between the theme's Night ink
  (`#ECE6DA`, halo `#0C0F13`) and Day ink (`#1B1E22`, halo `#FFFFFF`).
  Wallpapers never recolour the UI. Video or unreadable wallpapers follow
  the theme polarity and keep every cue on. The model is
  `services/clearink.js`.
- **Glyph-only halo and shadow.** Each entry gets one silhouette shadow in
  the halo colour (88 % alpha), never a box. Bar components read their
  colours from `tone` (`ink`, `inkMuted`, `signal`, `alert`); outside a
  clear bar `tone` is the plain Signal palette.
- **Styles** (`bar.clearStyle`, Layout Picker and Settings > Layout):
  Auto (1 px halo, plus a 4 px soft shadow on detailed regions), Outline,
  Shadow (2 px, falls back to Outline under 3:1) and Contrast (2 px halo,
  SemiBold). High Contrast forces Contrast.
- **Popouts** opened from a clear bar are ordinary opaque Signal panels.

The halo is an approximation of the spec's text outline: a MultiEffect
silhouette shadow, so it also rings meter segments and glyph icons.

## Ownership and persistence

The Shell owns live bar state and serializes it through `Config.qml`. Factory
defaults ship in `config/shell.default.json`; packaged layouts are installed
under the Hornero data catalogue. User changes live under
`$XDG_CONFIG_HOME/hornero/shell.json`. See [the path contract](PATH_CONTRACT.md)
and the [layout picker module](../shell/modules/layoutpicker/).

## Reordering sections

Control Center → **Bars** → *Sections & order* edits the active layout in
place: the bar set a preset wrote to `bar.bars`, or a screen's
`bar.perScreen` override when one exists (a scope picker appears then). Each
bar of the layout gets its own tab; entries move within and across the
start/center/end groups (shown as Left/Center/Right or Top/Middle/Bottom by
orientation), can be hidden (`enabled: false`), and missing sections can be
added at the end of the bar. Per-entry `options` and unknown fields are kept,
so the result is still a valid preset-shaped bar set. Choosing another layout
replaces the order with that layout's, exactly as before. The pure logic lives
in `modules/controlcenter/taskbar/barorder.js`.
