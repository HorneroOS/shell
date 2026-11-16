# Interaction grammar

How transient shell surfaces open, move, take focus and close. The design
authority is RFC 0001 (§3.6 motion, §4 anchored surfaces) and the Signal
visual language (§7 panels and popouts, §11 motion choreography) in
HorneroOS/docs. This page documents how the shell implements them.

## Anchored surfaces

Every popout, tray menu, tooltip and extension popover is an **anchored
surface**: one shared solver places it and one primitive animates it. No
layout, bar style or extension positions or animates its own popups.

| Piece | File | Role |
|---|---|---|
| `Placement.solve()` | `components/placement/Placement.js` | Pure solver: trigger rect, owning bar, screen, size in; rect, side, notch, origin, max size, flip/clamp/scroll out |
| `AnchoredSurface` | `components/placement/AnchoredSurface.qml` | Live anchor, placement, the morphing frame and the open/switch/track/close choreography |
| `SurfacePage` | `components/placement/SurfacePage.qml` | One content page: pinned to its placement, scan-in reveal, scrolls when clamped |
| `SurfaceFrame` | `components/placement/SurfaceFrame.qml` | `panel` fill, 1 px `rule` border, notch, registration tick, the one shadow |
| `AnchorTracker` | `components/placement/AnchorTracker.qml` | Live trigger rect through every ancestor, without polling |
| `Choreography` | `components/motion/Choreography.qml` | Motion level and every timing below |
| `Stagger`, `MotionAnim`, `FadeAnim` | `components/motion/` | Row stagger, named-curve animation, level-aware fade |

PluginKit ships a verbatim copy of the solver
(`plugin/qml/Hornero/PluginKit/Placement.js`, kept identical by
`tests/test_pluginkit_popover.py`), so extension tooltips and popovers
follow the same rules (see [PLUGINS.md](PLUGINS.md#anchored-popovers-and-tooltips)).

### Placement rules

The solver works in logical pixels in one global space, so every monitor
of a mixed-scale arrangement is solved the same way; the monitor scale is
used only to snap results to whole device pixels.

1. **Direction follows the owning bar.** Top bars open down, bottom bars
   up, left rails to the right, right rails to the left. A bar is the
   owner when the trigger lives in it (`Bar.surfaceOwner`); surfaces
   without a bar use `preferredSide` (`below`, `above`, `right`, `left`).
2. **Anchor line.** An attached bar's popout sits flush on the bar's
   inner edge (no border on that edge, square corners). Floating,
   island, inset, dock and Cockpit Clear bars keep a 4 px gap and all four
   borders. Clear bars have no slab to attach to, so their popouts are
   free-standing opaque `panel` cards.
3. **Cross axis.** Centred on the trigger, then clamped to the screen's
   usable rect (minus every bar's reservation) and an 8 px gutter.
4. **Flip once, then clamp and scroll.** A surface not owned by a bar
   flips to the opposite side when the preferred one cannot fit; it stays
   flipped while it still fits there (no oscillation during a live
   resize). A bar-owned surface never flips into its own bar. When
   neither side fits, the surface keeps its side, takes the largest size
   that fits and its page scrolls.
5. **Live anchor.** The trigger rect is re-read whenever the trigger or
   any ancestor moves or resizes (bar reorder, island resize, bar slide
   in, monitor change), and the surface follows without a stale frame. A
   trigger destroyed while its surface fades keeps the last known rect,
   so nothing teleports.
6. **Notch.** A 2 px `signal` line exactly as wide as the trigger runs
   along the anchor edge under it, so the surface visibly originates
   from its trigger even with motion off.

The Cockpit dual bar is the reference case: top popouts open down from
the top rail and never reach the bottom strip; bottom popouts open up from
the strip and stop below the top rail (`tests/placement/`).

### Motion

All durations and curves come from `Choreography`, which resolves the
motion level. Settle curves (`settle`, `settleFast`) move position, size
and shape only, never opacity or colour; past about 8 px of overshoot the
frame uses `enter` instead.

| Moment | Frame | Content |
|---|---|---|
| Open (click/keyboard) | Grows from the trigger notch (trigger-wide, zero depth on the anchor line) to its rect, `settle` 320 ms; opacity `enter` 90 ms | Rows scan in: 4 px travel from the anchor side plus fade, `enter` 160 ms, staggered 24 ms from 60 ms, at most eight rows |
| Open (hover) | Same, `settleFast` 220 ms | One block, no stagger |
| Switch (adjacent trigger while open) | Morphs from its current rect to the new one, `settle` 320 ms; never closes and reopens | Old page fades out 90 ms where it was, new page fades in `enter` 160 ms |
| Track (anchor or content size changes) | Follows with `settleFast` from wherever it is | Pinned, no reflow |
| Close | Fades with 4 px travel toward the anchor, `exit` 90 ms; no reverse morph | Fades with the frame |
| Tooltip | No morph: fade plus 4 px travel from the anchor, `enter` 90 ms; exit 90 ms | — |

Content is never scaled. Rows are found, not declared: `Stagger`
descends through single-child wrappers to the first container with two
or more visible children, so native popouts and extension popovers
stagger without opting in. Surfaces accept pointer and keyboard input from
their first frame; a click on a row that is still fading activates it.

Motion levels (visual language §11.3):

| Level | Used by | Behaviour |
|---|---|---|
| `full` | Signal mode | Everything above |
| `standard` | Everyday, Studio (default) | Everything above, same timings |
| `reduced` | Focus, low-power hardware | No morph, no stagger: the frame appears at its rect with 4 px travel and fade |
| `off` | Gaming, reduced motion | Instant; opacity fades capped at 90 ms |

`appearance.reducedMotion` or the desktop's reduced-motion preference
(`org.gnome.desktop.interface enable-animations`) forces `off`. The
experience-mode service sets `Choreography.modeLevel`; the user duration
scale (`appearance.anim.durations.scale`) multiplies every duration.

### Cost

Surfaces are instantiated once and toggled. The frame is plain rectangles
plus one analytic `RectangularShadow`; there is no `layer.enabled`, no
offscreen pass and no blur. Only geometry and opacity animate. The live
anchor is a binding over ancestor geometry, so it costs nothing while
nothing moves. Measurements live in `docs/perf-baselines/`.

## Hover, intent and focus

- **Open intent.** Hovering a bar trigger opens its popout after 120 ms
  of dwell. While a popout is open, hovering another trigger switches at
  once (the frame morphs).
- **Close grace.** Leaving the trigger and the surface starts a 240 ms
  grace; coming back cancels it. The gap between a floating bar and its
  card is part of the input region, so crossing it never closes the
  popout, and gaps between adjacent triggers are bridged by the grace.
- **Focus.** Hover popouts never take keyboard focus. Click and keyboard
  opens (status icons with Enter/Space, extension indicators) take focus,
  draw the registration tick and return focus to their trigger on
  Escape. Moving the pointer over the bar turns a click-opened popout
  back into a hover popout.
- **Explicit opens persist.** A click- or keyboard-opened popout ignores
  hover leave and closes on Escape, an outside click (the focus grab
  clears) or its trigger.

## Dismissal

Every transient shell surface dismisses from the keyboard. Inner content
with transient state gets the first Escape; anything unhandled falls
through to one central cascade.

### The Escape cascade

1. Inner state first: workspace rename cancels, armed session action
   disarms, the wireless password page steps back to the network list,
   dialogs close. Each accepts its own Escape.
2. Then the surface that holds the keyboard: a bar popout closes (and
   returns focus to its trigger), an extension popover closes.
3. Then the central cascade (`Drawers.dismissTopmost()`, attached to the
   drawers `Interactions` layer): layout picker, session, launcher,
   dashboard, sidebar, utilities — the topmost visible drawer closes.
4. OSD clears alongside any central dismissal: after Escape the drawers
   surface holds no transient UI.

One Escape closes exactly one surface. Standalone OSD keeps timer-only
dismissal on purpose: giving it keyboard focus would steal focus on every
volume or brightness change. Toasts likewise expire by timer (hover
pauses expiry).

### Key delivery: the grab

Physical keys reach the drawers surface through compositor-specific
layer-shell focus in `Drawers.qml`: Hyprland combines
`HyprlandFocusGrab` with `OnDemand`, while Niri uses `Exclusive` for an
explicit open because its top-layer `OnDemand` surface does not accept
keyboard focus from a shortcut. Both return to `None` when no drawer
holds keyboard intent (see `FOCUS.md`). Every drawer the cascade must
dismiss therefore needs keyboard intent on its keyboard-driven opens.

Niri also expands the pointer region only while an explicit transient is
open; a click outside that drawer closes it and releases exclusive
keyboard focus. The click is consumed by the dismissal, so click the
underlying window again to activate it.

Dashboard and utilities hover opens stay grab-free on purpose: an edge
touch must never steal typing from other apps. Explicit opens —
shortcut, IPC, action — set keyboard intent and grab instead. The two
are told apart at open time (`Interactions.on*Changed`): a flag flip
while the mouse is outside the area means keyboard-driven. A click inside
a hover-opened drawer is also keyboard intent (the dashboard rename field
needs it). Intent survives the shortcut-to-hover hand-off and clears when
the drawer closes. With `showOnHover: false` the dashboard can only open
explicitly, so it always grabs.

Separate windows keep their own handlers: Settings and Welcome floating
windows, the area picker, the session lock (which ignores Escape — it
must authenticate), and the companion menu below.

### Per-surface dismissal

| Surface | Escape | Click-outside | Other |
|---|---|---|---|
| Launcher | closes (central) | focus grab clears; Niri outside click closes and consumes the click | re-issue shortcut |
| Session | disarm, then close | focus grab clears; Niri outside click closes and consumes the click | re-issue shortcut |
| Dashboard | closes (central, explicit opens and clicks grab) | grab clears; Niri outside click closes and consumes the click; otherwise hover-leave | rename takes first Escape |
| Sidebar | closes (central) | focus grab clears; Niri outside click closes and consumes the click | re-issue shortcut |
| Utilities | closes when opened explicitly or clicked into; hover opens close on leave | grab clears; Niri outside click closes and consumes the click; otherwise hover-leave | a shortcut while the pointer already rests in the area counts as hover |
| Layout picker | closes (central) | focus grab clears; Niri outside click closes and consumes the click | re-issue shortcut |
| Bar popouts | closes, focus returns to the trigger | own grab clears | hover leave + 240 ms grace (hover opens only) |
| Extension popovers | closes (accepted, never reaches the cascade) | press outside | same as bar popouts when hosted in a bar |
| Tooltips | — | — | leave the trigger |
| OSD | clears with a drawer | — | timer |
| Companion menu | closes | grab clears | pick an entry |
| Companion bubble | — | — | left-click dismisses, right-click opens menu |
| Settings window | closes | n/a (real window) | X button, toggle |
| Welcome window | closes | n/a (real window) | X / Done buttons |
| Area picker | cancels | — | complete a selection |

## Bar affordances

Icon-only bar actions expose the same short name as a hover tooltip and
an accessible label; inline volume and brightness also announce their
current value and support wheel and arrow-key adjustment. When
active-window popouts are enabled, vertical rails keep the current-app
icon compact; hovering opens its title and live-preview card, and
assistive technology still receives the full window title. Turning that
popout off restores the visible rail title.

Hover is edge-triggered for the dashboard and utilities: entering the
area opens, leaving closes. An Escape/shortcut dismissal sticks while the
mouse sits still — only leaving and re-entering (fresh hover intent)
reopens.

## Settings search

`Ctrl+,` opens Find a setting in the floating Settings window. Results come
from `PaneRegistry.qml`, so page names, descriptions, aliases, and direct
section destinations stay alongside the routes they open. Type a page or a
common control such as wallpaper, VPN, reduce motion, fonts, or transparency;
use Up/Down to move and Enter to open it. Escape clears a query first, then
dismisses search, then closes Settings. `Super+,` remains available to the
desktop because the host keymap already assigns it to workspace navigation.
