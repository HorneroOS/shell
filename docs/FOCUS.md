# Focus + keyboard contract (S4)

Every semantically activatable Hornero control behaves the same from
keyboard and mouse. This file is the contract; `Interactive.qml` and
`FocusMode` are its single implementation.

## The contract

An activatable control (button, icon button, toggle, nav item,
selectable row/card, menu item, slider, text field, switch) supports:

- `Tab` / `Shift+Tab` moves focus to / past it (single tab stop per
  control; rows focus their inner control, never the row + control).
- Focus is visible: a 2 px `m3primary` ring drawn OUTSIDE the shape
  (no layout shift), only while keyboard-navigating.
- `Enter` activates; `Space` activates where semantically appropriate
  (buttons, toggles, switches, menu items — not text fields or links).
- Sliders additionally take arrows; menus take arrows + `Enter` to
  select and `Escape` to close (closing BEFORE the S3 drawer cascade).
- Mouse click activates; hover shows hover state, never the ring.
- `disabled` removes the control from tab order and ignores keys.
- Closing a drawer does not strand focus: the next `Tab` enters the
  first control of whatever holds keyboard next (verified, not
  assumed — see below).

Non-activatable `StateLayer`s (pure hover/pressed rendering with no
action) stay unfocusable. Never add tab stops to decoration.

## The layers (lowest correct wins)

- `services/FocusMode.qml` (singleton): one `keyboard` bool. Pointer
  press anywhere in shell chrome clears it; keyboard-driven focus
  sets it. The ring shows iff `activeFocus && FocusMode.keyboard`,
  so mouse clicks never leave stale rings and keyboard focus is
  never hidden.
- `components/controls/Interactive.qml`: `StateLayer` + tab stop +
  `Enter`/`Space` activation + outer ring + focus-reason report.
  Every StateLayer-based activatable control uses it (one-line
  swap); nothing else duplicates its `Keys` / focus / ring code.
- QtQuick Templates controls (`StyledSwitch`, sliders, radio,
  text fields) keep native key handling and only gain the shared
  ring + focus-reason report — no reimplemented key tables.
- `Menu.qml` owns arrow navigation + typeahead-free selection for
  its items (one menu implementation, not per-call-site `Keys`).

## Focus visuals

- Shape: 2 px solid ring, 2 px outside the control outline, radius
  following the control. Never a border-width flip on the control
  itself (that shifts layout, as the old ActionCard ring did).
- Color: `Colours.focusRing` (`m3primary`, theme-derived, so Dark /
  Light / Pampa follow automatically). Distinct by construction:
  hover is an 8% wash, pressed adds ripple, selected fills —
  the ring is the only primary outline floating off-shape.
- Contrast is verified by pixel inspection per theme (S4 evidence),
  not by token name.

## Focus reason without guessing

Qt does not tell QML why focus arrived. Each focusable reports at
`onActiveFocusChanged`: pressed-at-arrival means pointer, otherwise
keyboard. (`MouseArea.pressed` is already true when click-focus
lands; Tab arrives unpressed. Verified in nested validation.)

## Restoration

No competing Escape system: drawers close through S3
`dismissTopmost()`; menus and dialogs accept their own Escape first
(inner-state-first, as in `INTERACTION.md`). Closing drops
`keyboardExclusive` (below), so the compositor re-focuses the
previously keyboard-holding client itself — restoration needs no
focus hacks in the shell. If Qt ever strands keys (no focusable
accepts Tab), that is a bug in the surface, fixed there.

## Window activation (Exclusive, explicit opens only)

`HyprlandFocusGrab` routes physical keys to the surface but never
activates the Qt window: with a held grab and `OnDemand`, `Tab`
arrives yet `win.activeFocusItem` stays null and no traversal
runs (proven in VM validation — screenshots + `focusState`
probe). So the drawer surface takes `WlrKeyboardFocus.Exclusive`
while an explicitly-opened keyboard drawer is visible:

- `modules/drawers/Drawers.qml`: `keyboardExclusive` = launcher
  (explicit) | session | sidebar | dashboard (explicit) |
  utilities (explicit) | layoutPicker | tray submenu
  (depth > 1). Hover-only opens stay `OnDemand` so edge
  touches never steal typing; no drawer visible stays `None`.
- Explicitness reuses the S3 mouse-position inference
  (`Interactions.qml` `*ShortcutActive`: visible + mouse outside
  the panel area = shortcut/IPC/drag open). Launcher gains
  `launcherShortcutActive` mirroring dashboard/osd/utilities.
- Per-drawer initial focus (launcher search, session logout,
  …) already calls `forceActiveFocus()` on open; it only takes
  effect once the window actually activates — which is what
  this rule provides.

Observability: `qs ipc call debug focusState` reports window
activation, `FocusMode.keyboard`, grab state, the Exclusive
predicate and the `activeFocusItem` chain. Graphical and
agentic tests assert on it instead of guessing from pixels.
