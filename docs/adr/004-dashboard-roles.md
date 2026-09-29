# ADR 004 — The dashboard acts on the live session, never on persisted configuration

Date: 2026-09-29
Status: proposed

## Context

After ADR 003 removed the Layout tab, the dashboard holds five tabs
(`modules/dashboard/Tabs.qml`): Dashboard (home: user, clock,
calendar, resources, quick toggles, media/weather summaries),
Media (transport + player selection), Performance (resource graphs),
Weather (forecast), Workspaces (cards, detail, switch/rename/empty
actions). The home tab additionally hosts quick toggles (night,
game, record), workspace actions, and calendar navigation.

So the dashboard is already full of actions — "glance-only" would be
fiction. The question is the standing rule for what belongs: every
current control acts on live session objects (media players,
workspaces, recorder, game mode, calendar view, one-shot `horneroctl`
fires). None writes persisted shell configuration (`shell.json`):
durable settings live in the Control Center window (`WindowFactory`),
which is exactly why the Layout grid left the dashboard in ADR 003.

## Options

1. **Glance-only dashboard.** Contradicted by the tree: media
   transport, workspace switching, and toggles would all have to go,
   gutting the drawer the overhaul just made useful.
2. **Anything-goes actions.** Recreates the ADR 003 problem one level
   down: settings duplicated into a status surface, two mental models
   per control.
3. **Session-acts rule.** The dashboard shows live session state and
   acts on it in place; anything that writes persisted configuration
   belongs in Settings (a dashboard control may deep-link there, never
   duplicate the control).

## Decision

Option 3. Per-tab roles:

- Dashboard (home) — session right now: who, when, load, one-tap
  session switches (night/game/record), workspace jumps.
- Media — the active player, operated in place (transport, selection).
- Performance — resource truth, read-only.
- Weather — forecast, read-only.
- Workspaces — the compositor session, operated in place
  (switch, rename, empty, special workspaces).

Admission test for any new dashboard control: it must act on a live
session object visible on the same surface. If it writes persisted
configuration, it belongs in Settings — link, don't duplicate.

## Consequences

- All five current tabs comply as written; no code changes follow
  from this ADR.
- The QuickToggles night chip stays: it fires a one-shot session
  change, it does not own the night-mode setting (Settings does).
- Future dashboard controls are judged by the admission test; a
  concept that needs persisted controls writes a new ADR superseding
  this one instead of silently adding them.
