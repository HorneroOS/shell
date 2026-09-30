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

Separate windows keep their own handlers: Settings and Welcome
floating windows, the area picker, the session lock (which ignores
Escape — it must authenticate), and the companion menu below.

## Per-surface dismissal

| Surface | Escape | Click-outside | Other |
|---|---|---|---|
| Launcher | closes (central) | focus grab clears | re-issue shortcut |
| Session | disarm, then close | focus grab clears | re-issue shortcut |
| Dashboard | closes (central) | grab iff hover off, else hover-leave | rename takes first Escape |
| Sidebar | closes (central) | focus grab clears | re-issue shortcut |
| Utilities | closes (central) | focus grab clears | hover-leave also hides |
| Layout picker | closes (central) | focus grab clears | re-issue shortcut |
| Bar popouts | closes (own handler) | own grab clears | re-click trigger |
| OSD | clears with a drawer | — | timer |
| Companion menu | closes | grab clears | pick an entry |
| Companion bubble | — | — | left-click dismisses, right-click opens menu |
| Settings window | closes | n/a (real window) | X button, toggle |
| Welcome window | closes | n/a (real window) | X / Done buttons |
| Area picker | cancels | — | complete a selection |

Hover is edge-triggered for the dashboard and utilities: entering
the area opens, leaving closes. An Escape/shortcut dismissal sticks
while the mouse sits still — only leaving and re-entering (fresh
hover intent) reopens. Hover feel for pure mouse users is unchanged.
