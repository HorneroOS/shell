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

Physical keys reach the drawers surface through the
`HyprlandFocusGrab` in `Drawers.qml`, and the surface's keyboard
interactivity follows that grab exactly (`OnDemand` while grabbed,
`None` otherwise; see `FOCUS.md`). Every drawer the cascade must
dismiss therefore needs grab coverage on its keyboard-driven opens.

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
| Launcher | closes (central) | focus grab clears | re-issue shortcut |
| Session | disarm, then close | focus grab clears | re-issue shortcut |
| Dashboard | closes (central, explicit opens and clicks grab) | grab clears, else hover-leave | rename takes first Escape |
| Sidebar | closes (central) | focus grab clears | re-issue shortcut |
| Utilities | closes (central, explicit opens and clicks grab) | grab clears, else hover-leave | — |
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
