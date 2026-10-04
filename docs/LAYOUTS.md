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

Bar actions reference IDs in `services/ShellActions.qml`, never shell command
strings. Current actions include launcher, layout picker, dashboard, session,
settings, and screenshot. Unknown actions are skipped with a warning.

## Shipped presets

The installed catalogue contains 15 presets. It includes Hornero Left/Right,
Cockpit and Cockpit Clear, Horizon, Islands, Cozy Minimal, Dock Bottom, and
focused minimal, classic, gaming, floating, and productivity arrangements.
Every preset is an explicit multi-bar specification and is validated by
`tests/test_shell_layout.py`.

`horneroctl shell preset list --full` reports display metadata and topology for
the Layout Picker. `horneroctl shell preset apply <name> --yes` applies a
preset to the user-owned Shell settings file; installed system presets are
read-only and are never changed.

## Ownership and persistence

The Shell owns live bar state and serializes it through `Config.qml`. Factory
defaults ship in `config/shell.default.json`; packaged layouts are installed
under the Hornero data catalogue. User changes live under
`$XDG_CONFIG_HOME/hornero/shell.json`. See [the path contract](PATH_CONTRACT.md)
and the [layout picker module](../shell/modules/layoutpicker/).
