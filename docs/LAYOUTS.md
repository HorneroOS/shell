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
  "margin": 6,
  "thickness": 34,
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
| `margin` | 0–256 px | 6 |
| `thickness` | 20–256 px (the whole bar body; density-scaled) | `bar.sizes.innerWidth` |
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
`workspaces.style` (`pills` or `labels`), `media.maxWidth`, and `pinnedApps.iconSize` (16 to 40 px).

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

The installed catalogue contains 16 presets. It includes Hornero Left/Right
(inspired by Caelestia's layout, preserved with attribution), Cockpit (an inset
top rail to act and an inset bottom strip to know) and Cockpit Clear (same
anatomy, no bar backdrop at all — adaptive per-region ink only), Horizon,
Islands, Floating Island, Minimal Float (formerly Cozy Minimal), Dock Bottom,
Classic Top/Bottom, Minimal Top/Left, Productivity, Studio, and Gaming.
**Cockpit is the factory default** (`config/shell.default.json`, Experience
profiles, `horneroctl` reset); Hornero Left/Right stay supported presets.

Floating Island and Productivity were removed in the first Signal audit
(shell#484) and are restored here, redesigned in Signal Bezel: hairline
frames, 3 px radii, no glass. A persisted Experience `layout.preset` naming
either is kept; `services/experience.js` only migrates ids listed in
`RETIRED_PRESETS`, which is empty because no shipped preset is retired. Every
preset is an explicit multi-bar specification and is validated by
`tests/test_shell_layout.py` and `tests/test_thin_bars.py`.

### Proportions

Bars are refined, not infinitesimal. Thickness is the bar body; the margin is
the gap to the screen edge (floating and inset styles) and is added to the
reservation. Every slab carries a 1 px `rule` hairline (all round when
floating or inset, inner edge only when attached), radii are at most 4 px and
nothing is translucent glass.

| Preset | Edge: style, thickness, margin | Personality |
| --- | --- | --- |
| Cockpit | top: inset 42, 18, radius 11 / bottom: attached 28, flush | Flagship: a rounded floating pill to act on, a flush square strip to know below |
| Cockpit Clear | top: attached 46 / bottom: attached 30, both flush, no slab | Same content, no background: only adaptive ink, workspace labels with an underline |
| Horizon | top: inset 34, 6 / bottom (clear): inset 26, 6 | One instrument line plus a clear workspace line |
| Classic Top / Bottom | attached 36 (cell 28, content 110 %) | Conventional single bar |
| Minimal Top | top: attached 34 (cell 26) | Quiet: workspaces, clock, power |
| Minimal Float | top: floating 34, 8 (cell 26) | One quiet floating strip |
| Floating Island | top: floating 34, 10 | One compact centred module: workspaces, clock, status |
| Islands | top: islands 36, 8 (cell 28) | Three separate rack modules |
| Productivity | top: inset 36, 6 (cell 28) | Calm focused work: workspaces, active window, clock, essential tray |
| Studio | top: attached 36 (cell 28) | Media and meters beside the clock |
| Gaming | bottom: floating 32, 8 (no reservation) | Out of the way overlay |
| Dock Bottom | bottom: dock 50, 8 | Console dock with 28 px app tiles |
| Hornero Left / Right | attached 60 (cell 44, content 125 %) | Chunky Caelestia-inspired rail: roomy cells, 20 px icons, 15 px labels |
| Minimal Left | left: attached 48 (cell 36, content 115 %) | Instrument rail |

The density factor (`services/density.js`) scales these gently: at most 6 %
smaller on a 720p screen and 10 % larger at 2160p. Primary text never drops
below 12 px, bar icons stay between 15 and 18 px, segment padding never below
8 px (6 px in rails), and a bar is never thinner than the 24 px hit area.
`bar.sizes.densityScale` (0.75 to 1.5) multiplies on top.

`horneroctl shell preset list --full` reports display metadata and topology for
the Layout Picker. `horneroctl shell preset apply <name> --yes` applies a
preset to the user-owned Shell settings file; installed system presets are
read-only and are never changed.

## Segments and the mode indicator

Bar entries are **segments** (signal-visual-language §4.1): 12 px horizontal
padding (8 px vertical in left/right rails), no spacing in the group, and a
1 px `rule` between segments inset 6 px from the bar edges (22 px tall in a
34 px rail). Adjacent icon-only entries (`quickActions`, `statusIcons`,
`tray`, `extensions`) form one segment with a 10 px gap and no rule.
Cockpit Clear draws no rules.

`modeIndicator` is a compact experience-mode indicator (shell#478): the
mode glyph and, outside `icons` density, a three-letter eyebrow (`FOC`,
`SIG`, `GAM`, `STU`). It is hidden in Everyday and shown in every other
mode; `options.always: true` keeps it visible. Cockpit and Cockpit Clear
ship it first in the top rail's end group. Click opens Settings.

## Chromatic discipline and the mark

Bar foregrounds are `ink` or `inkMuted`. `signal` (amber) marks only the
mark, the active workspace bar, the mode chip, on-air chips and a live
interaction; `alert` marks only urgent states. The clock is one colour. Slider
fill and thumb are ink at rest and turn amber only while dragged. Tray and
extension icons are recoloured monochrome by default (`bar.tray.recolour`,
`bar.extensions.recolour`; set either to `false` for full-colour icons).
`bar.mark` is `hornero` (the symbolic mark in `signal`, default) or `distro`
(the base distribution logo, in ink). `tests/test_bar_chroma.py` guards this.

## Cockpit Clear

`backdrop: "clear"` bars have a genuinely absent background (RFC 0001 §5.1):
no fill, tint, slab, blur, edge scrim or backdrop shadow, in every mode
including High Contrast. Legibility comes only from the foreground:

- **Adaptive ink.** `components/clearink/ClearInkField.qml` draws the
  wallpaper once (on wallpaper or screen change, never per frame) into a
  192-column luminance grid. Each bar entry owns a `ClearInkTone`. Auto
  keeps the theme's own polarity (Night ink `#ECE6DA`, Day ink `#1B1E22`)
  while it holds 4.5:1 against the wallpaper next to the strokes (with the
  halo laid under them) and 2.2 x the raw contrast, and flips only where it
  does not, so a bar reads as one ink on most wallpapers. Wallpapers never
  recolour the UI. Video or unreadable wallpapers follow the theme
  polarity. The model is `services/clearink.js`.
- **Glyph-only rim and shadow.** Each entry gets a silhouette halo in the
  polarity's halo colour, never a box: a 1 px rim at 50 % plus a soft 3 px
  drop shadow (4 px on detailed regions) in Auto. The shader
  (`assets/shaders/clearinkhalo.frag`) carries separate ring and shadow
  alphas. Bar components read their colours from `tone` (`ink`,
  `inkMuted`, `signal`, `alert`); outside a clear bar `tone` is the plain
  Signal palette. Tray icons and extension text follow the region ink.
- **Styles** (`bar.clearStyle`, Layout Picker and Settings > Layout):
  Auto (rim plus soft shadow), Outline (1.5 px firm ring), Shadow (4 px
  soft drop) and Contrast (2 px ring plus shadow, SemiBold). High Contrast
  forces Contrast. `bar.clearInk.{polarity,strength,outline}` fine-tune any
  style (Auto/Light/Dark ink, 0 to 150 % strength, 0 to 200 % ring width).
- **Item style.** Clear ships `bar.typeface: "sans"`, `iconScale` 0.9,
  `textScale` 1.1, `itemSpacing` 2: one quiet foreground voice (Plex
  Sans, sentence case, no tracking, tabular figures only for numbers), one
  glyph set at one optical size, icons in the primary ink, a 2 px / 1 px
  rule slider with a tick, thin 2 px meter segments. All of it is under
  Bars > Size & shape.
- **Popouts** opened from a clear bar are ordinary opaque Signal panels.

The halo is computed per entry by a shader over the entry's silhouette, so
it also covers meter segments and glyph icons.

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

## Bar size, density and the controls

Bars are refined, never fat, but also never cramped. Shipped thickness is
42 px (Cockpit top pill) and 46 px (Cockpit Clear top), 28 and 30 px (their flush bottom strips), 26 px (Horizon's bottom line), 34 to 36 px for the
horizontal layouts, 32 px for the Gaming overlay and 50 px for the dock.
The Hornero Left/Right rails are chunky on purpose: 60 px with 44 px cells,
which is the 56 to 64 px rail of the original Caelestia sidebar, with
`contentScale` 1.25 so icons are 20 px and workspace and clock labels 15 px
(shell#583). Radii stay at most 3 to 5 px and hairlines 1 px. `thickness` is
the whole bar body: there is no extra frame padding around it.

`services/Density.qml` derives one density factor from the screen's logical
height (physical height divided by the compositor scale: 1280x720 is 0.86,
1366x768 is 0.89, 2560x1440 at 1.5 and 1920x1080 are 0.96 and 1.0, 3840x2160
at 2 is 1.0) and scales bar thickness, `bar.sizes.innerWidth`, segment
padding, icons (15 to 18 px), text (12 to 13 px) and the clock, then
`bar.sizes.contentScale` multiplies icons, text and clock on top. Bars never
go below 24 px (the full bar height is every segment's hit target). Popouts
anchor to the scaled bar, so any thickness keeps them correct.

### Island inset and the active-workspace inset

Islands (the workspace track, tray, status and extension chips) do not touch
the bar's cross-axis edges. `bar.sizes.islandInset` is the least gap, in px at
density 1; it scales with the density factor (so with the bar thickness) and
takes at most a quarter of the bar body per side. The cell size
(`bar.sizes.innerWidth`) stays the upper bound: the island is
`min(cell, thickness - 2 * inset)` tall (never under 18 px), so thick rails
(60 px, cell 44: 8 px each side) keep their roomier natural gap and thin
strips (Cockpit bottom, 28 px) now keep 4 px instead of 2.
`bar.workspaces.activeInset` insets the active-workspace highlight inside its
track the same way (the full inset on the cross axis, half along the bar), and
never leaves less than a numeral's height.

History: the first Hornero bars (imported from the Caelestia-derived tree)
held every island `max(padding.smaller, border.thickness)` px inside a
`innerWidth + 2 * padding` body. #520 (thin bars) cut that body padding to 0
and let islands fill `innerWidth` of a density-scaled thickness, so on thin
bars the gap collapsed to a side effect of two unrelated numbers (28 - 24 = 2
px). The inset is now its own control with a default, not a leftover.

Cockpit Clear ships both insets at 0: its reference draws no island and the
workspace underline is flush with the bar edge, so there is nothing to
inset. Every other layout ships 4.

### Workspace cells

The workspace strip is one instrument: every workspace is one cell of the same
cross-axis size (the track minus the active inset on both sides), on top bars,
bottom bars and left or right rails alike. The cell rule is fixed:

- Numeral box: a square of at least the cell size (wider only when the widest
  numeral needs it; the box is shared by every cell, so one and two digit
  workspaces line up).
- Window glyphs follow the numeral after a fixed gap, one fixed-size slot per
  glyph at numeral x-height scale (`bar.workspaces.glyphScale`, default 85 % of
  the numeral). A cell therefore grows by exactly one glyph step per window,
  nothing overlaps and there are no negative margins. More windows than
  `bar.workspaces.maxWindowIcons` (default 3) end in a `+N` mark.
- States share one rounded rectangle at the cell's own size: empty is a
  hairline, occupied a quiet plate, active the brighter plate that slides
  between cells with a 2 px signal tick inset on the edge facing the content,
  urgent an alert hairline and numeral, visible on another monitor a strong
  hairline. Plates never merge across cells.
- Cockpit Clear and the `labels` style draw no plates: foreground only. The
  numeral and glyphs carry the state, occupied adds a 4 x 2 px tick under the
  numeral, active a flush signal underline on the content-facing edge.
- All colours are Signal roles; motion uses the shared animation durations,
  so reduced motion shortens or removes the slide.

Controls (Control Center, Bars, "Size & shape"): "Workspace window glyph size
(%)" (`bar.workspaces.glyphScale`, 60 to 120), "Workspace window glyphs per
cell" (`bar.workspaces.maxWindowIcons`, 0 to 8) and the existing active
workspace inset; "Reset all sizes" restores the layout's values. "Show
windows", "Occupied background" (cell plates) and "Active indicator" stay in
the Taskbar pane. `tests/test_workspace_render.py` renders Cockpit, Hornero
Left and Cockpit Clear offscreen and checks that cells do not overlap and
glyphs stay inside their cell.

### Every value is a control

The defaults above are only defaults. Control Center, Bars, "Size & shape"
edits the live config (the real bars follow while you drag; a to-scale strip
shows the selected bar) and every control validates against the same limits
as `config/BarConfig.qml`:

| Control | Config key | Range |
| --- | --- | --- |
| Thickness (per bar) | `bar.bars[].thickness` | 24 to 96 px |
| Gap to screen edge (per bar) | `bar.bars[].margin` | 0 to 24 px |
| Corner radius (per bar) | `bar.bars[].radius` | 0 to 24 px, -1 (default) keeps the style's own radius |
| Style (per bar) | `bar.bars[].style` | attached, inset, floating, islands, dock |
| Edge (per bar) | `bar.bars[].edge` | top, bottom, left, right (one bar per edge) |
| Density (per bar) | `bar.bars[].density` | values, glyphs |
| Cell size | `bar.sizes.innerWidth` | 22 to 56 px |
| Island inset | `bar.sizes.islandInset` | 0 to 12 px at density 1 (default 4; Cockpit Clear 0) |
| Active workspace inset | `bar.workspaces.activeInset` | 0 to 8 px at density 1 (default 4; Cockpit Clear 0) |
| Workspace window glyph size | `bar.workspaces.glyphScale` | 60 to 120 % of the numeral (default 85) |
| Workspace window glyphs per cell | `bar.workspaces.maxWindowIcons` | 0 to 8 (default 3, then `+N`) |
| Icon and label size | `bar.sizes.contentScale` | 75 to 150 % |
| Icon size | `bar.sizes.iconScale` | 60 to 150 % |
| Text size | `bar.sizes.textScale` | 75 to 150 % |
| Text weight | `bar.sizes.textWeight` | 300 to 600 |
| Space between items | `bar.sizes.itemSpacing` | 50 to 200 % |
| Text face | `bar.typeface` | mono or sans |
| Density | `bar.sizes.densityScale` | 75 to 150 % |
| Follow screen height | `bar.sizes.autoDensity` | on, off |
| Corner radius | `appearance.rounding.scale` | 50 to 200 % |
| Gap between items | `appearance.spacing.scale` | 75 to 150 % |
| Padding | `appearance.padding.scale` | 75 to 150 % |

"Reset this bar" and "Reset all sizes" return to the values the active layout
preset ships (read from the preset JSON next to the shell), or to the factory
fallbacks when the layout is custom. The pure logic lives in
`modules/controlcenter/taskbar/bargeometry.js`; the controls edit the global
bar set (per-screen overrides keep their own values).

### My tweaks for a layout

A layout preset rewrites the bars and sizes, so a person who tuned them loses the tuning on every switch. Control
Center, Layout, "My tweaks for this layout" saves the current values as that layout's override row
(`layouts.overrides.<layout id>` in `shell.json`, empty by default). Layers, lowest first: factory defaults, preset,
layout override, experience-mode override, user edits.

Overridable keys (validated and clamped like their controls): `bar.sizes.{innerWidth, contentScale, iconScale,
textScale, textWeight, itemSpacing, densityScale, autoDensity}`, `bar.typeface`, `appearance.{rounding, spacing,
padding}.scale`. Bar topology (edges, styles, groups, per-bar thickness) is the preset's and is never overridden.
After a preset applied from the shell (Layout pane, quick picker, an experience mode's preferred layout, factory
reset) succeeds, the row is applied about 0.9 s later, once the rewritten `shell.json` has been reloaded. A preset
applied directly with `horneroctl` does not go through the shell: use "Use my tweaks now" (it offers Undo). "Forget" returns the layout
to its preset. Logic: `services/layouts.js`, shell wiring `services/Layouts.qml`.
