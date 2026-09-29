# ADR 003 — Shell layout presets live in the picker + Settings, not the dashboard

Date: 2026-09-29
Status: proposed

## Context

Shell layout presets (bar arrangements from `horneroctl shell preset list
--full`, applied instantly via `horneroctl shell preset apply`) are
currently reachable from three surfaces hosting the same shared
`PresetGrid`:

1. The drawer quick picker (`Super+Shift+B`) — modal, keyboard-first
   (`keyboardNav`, arrows/Enter/Esc), fastest switch path.
2. The Control Center Layout pane (`layout/LayoutPane.qml`) — explainer
   copy plus a tip advertising the drawer shortcut; the discoverable
   settings home.
3. The dashboard Layout tab (`LayoutPickerView.qml`) — the bare grid
   with no explainer, no shortcut tip, no keyboard hints.

The dashboard's other tabs (Dash, Media, Performance, Weather,
Workspaces) are glanceable status/info. Layout switching is an action,
not status, and the dashboard tab adds no context the other two
surfaces lack. Three hosts for one grid is accidental duplication, not
progressive disclosure: a newcomer meeting layout in three places
learns three mental models for one control.

## Options

1. **Remove the dashboard Layout tab** (keep drawer picker + CC pane).
   Drawer stays the quick switch, CC stays the discoverable home.
2. **Keep all three** and document the roles. Zero code churn, but
   preserves the three-models-for-one-control problem the overhaul
   exists to eliminate.
3. **Merge the CC pane into the dashboard.** Larger IA churn in the
   opposite direction: it would move a setting out of Settings into a
   status surface.

## Decision

Option 1. The dashboard returns to status/info tabs; layout preset
switching keeps exactly two homes with distinct roles:

- drawer picker — quick, keyboard-first switch;
- Control Center Layout pane — explained, discoverable settings home
  (it already points at the drawer shortcut).

Removal details: drop the tab button, the `Pane` entry, and the now
unreferenced `LayoutPickerView.qml`. `dashboardState.currentTab`
survives in-process config reloads via `reloadableId` (in-memory
handoff only — it never touches disk), so both tab consumers clamp a
stale index 5 down to the last tab: a user who last had Layout open
and reloads mid-session lands on Workspaces instead of an
out-of-range blank.

## Consequences

- One fewer dashboard tab; Dash/Media/Performance/Weather/Workspaces
  keep their indices (removal is trailing, so carried-over 0–4 are
  unaffected).
- Users who knew layout only via the dashboard find it in Settings
  Layout (same grid) or `Super+Shift+B` (advertised there).
- If a future dashboard concept needs actions again, write a new ADR
  superseding this one — do not silently re-add the tab.
