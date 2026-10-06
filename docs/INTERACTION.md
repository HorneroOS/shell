# Interaction grammar: dismissal

Every transient shell surface dismisses from the keyboard. Inner
content with transient state gets the first Escape; anything
unhandled falls through to one central cascade.

## The Escape cascade

1. Inner state first: workspace rename cancels, armed session action
   disarms, dialogs close. Each accepts its own Escape.
2. Then the central cascade (`Drawers.dismissTopmost()`, attached to
   the drawers `Interactions` layer): layout picker, session,
   launcher, dashboard, sidebar, utilities — the topmost visible
   drawer closes.
3. OSD clears alongside any central dismissal: after Escape the
   drawers surface holds no transient UI.

Standalone OSD keeps timer-only dismissal on purpose: giving it
keyboard focus would steal focus on every volume or brightness
change. Toasts likewise expire by timer (hover pauses expiry).

## Key delivery: the grab

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

Dashboard and utilities hover opens stay grab-free on purpose: an
edge touch must never steal typing from other apps. Explicit opens —
shortcut, IPC, action — set keyboard intent and grab instead. The two
are told apart at open time (`Interactions.on*Changed`): a flag flip
while the mouse is outside the area means keyboard-driven. A click
inside a hover-opened drawer is also keyboard intent (the dashboard
rename field needs it). Intent survives the shortcut-to-hover
hand-off and clears when the drawer closes. With
`showOnHover: false` the dashboard can only open explicitly, so it
always grabs.

Separate windows keep their own handlers: Settings and Welcome
floating windows, the area picker, the session lock (which ignores
Escape — it must authenticate), and the companion menu below.

## Per-surface dismissal

| Surface | Escape | Click-outside | Other |
|---|---|---|---|
| Launcher | closes (central) | focus grab clears; Niri outside click closes and consumes the click | re-issue shortcut |
| Session | disarm, then close | focus grab clears; Niri outside click closes and consumes the click | re-issue shortcut |
| Dashboard | closes (central, explicit opens and clicks grab) | grab clears; Niri outside click closes and consumes the click; otherwise hover-leave | rename takes first Escape |
| Sidebar | closes (central) | focus grab clears; Niri outside click closes and consumes the click | re-issue shortcut |
| Utilities | closes when opened explicitly or clicked into; hover opens close on leave | grab clears; Niri outside click closes and consumes the click; otherwise hover-leave | a shortcut while the pointer already rests in the area counts as hover |
| Layout picker | closes (central) | focus grab clears; Niri outside click closes and consumes the click | re-issue shortcut |
| Bar popouts | closes (own handler) | own grab clears | re-click trigger |
| OSD | clears with a drawer | — | timer |
| Companion menu | closes | grab clears | pick an entry |
| Companion bubble | — | — | left-click dismisses, right-click opens menu |
| Settings window | closes | n/a (real window) | X button, toggle |
| Welcome window | closes | n/a (real window) | X / Done buttons |
| Area picker | cancels | — | complete a selection |

## Settings search

`Ctrl+,` opens Find a setting in the floating Settings window. Results come
from `PaneRegistry.qml`, so page names, descriptions, aliases, and direct
section destinations stay alongside the routes they open. Type a page or a
common control such as wallpaper, VPN, reduce motion, fonts, or transparency;
use Up/Down to move and Enter to open it. Escape clears a query first, then
dismisses search, then closes Settings. `Super+,` remains available to the
desktop because the host keymap already assigns it to workspace navigation.

Bar popouts keep the trigger's centre on the bar's long axis, then unfold from
the edge the trigger lives on: down from top bars, up from bottom bars, inward
from left or right rails. Icon-only bar actions expose the same short name as
a hover tooltip and an accessible label; inline volume and brightness also
announce their current value and support wheel and arrow-key adjustment.
Tooltips move to the nearest usable side of their trigger and stay within the
screen on top, bottom and vertical bars. When active-window popouts are
enabled, vertical rails keep the current-app icon compact; hovering opens its
title and live-preview card, and assistive technology still receives the full
window title. Turning that popout off restores the visible rail title.

Hover is edge-triggered for the dashboard and utilities: entering
the area opens, leaving closes. An Escape/shortcut dismissal sticks
while the mouse sits still — only leaving and re-entering (fresh
hover intent) reopens. Hover feel for pure mouse users is unchanged.
