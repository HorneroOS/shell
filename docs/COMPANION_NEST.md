# Javi's Nest: runtime habitat

The Nest is ambient desktop chrome, not a window. It is a small
`Bottom`-layer surface (`modules/companion/NestHabitat.qml`) separate from
Javi's own surface, with no keyboard focus, no exclusive zone, no taskbar
entry and an empty input region unless the user gave it a click action.

Art status: the nest frames are a clearly marked placeholder drawn by
`scripts/companion_nest.py` (`Habitat.ART.status == "placeholder"`, repeated
in the Control Center). Placement, lighting, modes and the lights below are
final logic and carry over when the master art lands.

## Policy

All decisions are pure functions in `modules/companion/habitat.js`, tested
under node (`tests/test_companion_habitat.py`):

| Concern | Rule |
| ------- | ---- |
| Level | Per Experience mode: `hidden`, `dim`, `normal`, `rich`. Defaults: Focus dim, Everyday normal, Signal rich, Gaming hidden, Studio dim. Quiet hours (the window set under Reactions) step the level down one notch (rich to normal, normal to dim) and never to hidden. Choices are stored per mode and never rewritten when the mode changes. |
| State | `hidden`, `resting`, `working`, `building`, `sleeping`, `summoned`, derived only from the companion store (visible, state, one-shot animation) and the assistant bridge (run in flight, approval or clarification pending). |
| Lights | Five sockets in the art. Lit only by real signals: `link` (assistant enabled and gateway reachable, or red when enabled but unreachable), `run` (a run in flight), `approval` (a request is waiting, the only light that blinks), `radio` (a Radio question in flight), `mode` (steady, colour per mode). Lights never carry content. |
| Blinking | Only the approval light, at most 1.4 Hz, only at normal or rich level, awake, with motion allowed. One 700 ms timer exists only while a light blinks. |
| Colour | Palette roles, not literals: Follow theme uses the live Chromatic palette (`phosphor`, `signal`, `cue`, `alert`); Warm and Cool pin the family; alerts always use `alert`. Javi's anatomy is never recoloured. |
| Surface | Wanted only when companion and nest are enabled, placement is "own corner", the level is not hidden, the companion is visible (not locked, fullscreen, gaming, area picker or Settings open) and the nest has at least one stage. Otherwise the surface and its timers do not exist. |
| Layout | Corner, margins, scale and monitor are settings; the nest is clamped to stay fully on screen. Javi's sleep-at-nest flight targets the habitat when anchored. |

## Input region

The companion window now declares an explicit input mask covering only the
sprite box and, while open, the speech bubble, the chat card and the menu.
The transparent remainder of the surface no longer blocks clicks on windows
below it. The nest surface is click-through unless "Click on the nest" is
not Nothing, and then only the art square takes clicks.

## Settings (Control Center, Javi, Nest)

Placement (own corner or beside Javi), corner, margins, size, monitor,
lighting, light intensity, indicator lights, screen glow while the
assistant works, dim in quiet hours, click action, and a level per mode.
Every control has a Reset and writes one key of the validated `habitat`
preference document (`CompanionStore.patchPref("habitat", ...)`).

Not built (waiting on art, not faked): decorative accessory toggles and
per-component skins of the nest, and the sleeping pose inside the nest.
