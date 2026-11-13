# Javi (the Companion) ↔ Assistant mapping

The companion is **Javi, el Hornero** — presentation with a
Hornero 199X retrofuturist chat aesthetic (phosphor status light,
mono micro-labels, scanline header accent; reduced-motion disables
the shimmer). The assistant is a separate backend (see
`docs/adr/002-companion-assistant-boundary.md`) driven over the
`companion` IPC target. `AssistantBridge.qml` runs
`horneroctl assistant ask --json --stream` (Hermes Agent via
horneroctl's consent gates), consuming NDJSON delta lines for live
streaming and the final CommandResult line for the structured
outcome (answer, pending approval, pending clarification — read
from payload data, never parsed from prose). The chat also renders
the run's activity trace live (`horneroctl` NDJSON `thinking` /
`tool` / `commentary` frames, classified in
`assistant_event_trace`): provider reasoning previews, tool
lifecycle with command previews, and mid-turn commentary. This is
the gateway's emitted activity — providers do not expose raw
chain-of-thought — and each answer bubble keeps its trace behind a
SHOW ACTIVITY TRACE toggle. `askStop()` now stops
the Hermes run server-side too (`assistant stop <runId>`, shell#223)
while it is known.

The launcher can also ask inline (shell#250 slice 3): `>ai <question>`
streams the answer inside the launcher via
`services/InlineAsk.qml` (a shell-lifetime singleton; only the last
question/answer is kept in memory, nothing is persisted), using the same
`horneroctl assistant ask --json --stream` path, registered as the
`ai` provider on the launcher's provider registry. It is deliberately
one-shot: no history, no attachments, and approvals/clarifications
are never answered there — a failed or pending run turns the row
into a fallback that summons this chat panel with the same question
(the pre-inline `>ai` behaviour). Closing the launcher or leaving
the `>ai` route cancels an in-flight inline run. See
`docs/LAUNCHER.md`, "Inline AI", for modes, privacy and the
documented `--mode` gap.

The native chat panel (`ChatPanel.qml`,
`qs ipc call companion chat`) is a scrollable bubble conversation
with markdown rendering, suggestion chips, retry, clear, and
persistent shell-side history
(`$XDG_STATE_HOME/hornero/companion/chat-history.json`, capped by
the Javi pane; Hermes owns real sessions). Attachments go through
horneroctl validation (`--attach`: images as `input_image`, text
inlined with caps, secret-looking files refused). Voice notes are
recorded with `pw-record` and sent as an audio attachment that
Hermes transcribes. Approvals and clarifications are always
explicit user actions — never auto-answered. The assistant is
disabled by default and never required. Control Center › Javi
carries the Assistant (Hermes) settings section (status,
enable/disable, streaming, history retention; keys never enter QML).

## Reserved states → animations (live now)

| Future state | Animation | Shown as |
| ------------ | --------- | -------- |
| `listening` | `listen` | head cocked — "I'm hearing you" |
| `thinking` | `think` | head tilt, half eye — "working on it" |
| `acting` | `work` | carrying a twig — "doing it" |
| `success` | `approve` | wing raised with a hop — "done" (settles to idle) |
| `warning` | `worry` | worried crouch — "heads up" (loops until decided) |
| `denied` | `deny` | head shake — "that was not allowed" (settles to idle) |
| `error` | `error` | droop — "that failed" (settles to idle) |

Set them exactly like behavior states:

```sh
qs ipc call companion setState listening
qs ipc call companion say "On it — one moment." 5000
qs ipc call companion setState success
```

Unknown states warn and are ignored; unknown animations fall back to
`idle`. `companion status()` reports the resolved animation so a
daemon can verify what the user sees.

## Manifest assistant states (asset layer)

`assets/companion/manifest.json` also carries `assistantStates`
(`resting` → idle, `listening` → listen, `thinking` → think,
`acting` → work, `speaking` → talk, `success` → approve,
`warning` → worry, `denied` → deny, `error` → error), consumed via
`Companion.stateSource(state)` for static (non-overlay) surfaces.
The overlay host maps the daemon states above to the same reels, so
both layers agree on what each state looks like.

## Rules for the future daemon

1. Drive the companion **only** through `qs ipc call companion …`.
2. Prefer `say`/`tip` for user-visible text; keep bubbles short
   (280 chars max, auto-dismissed).
3. Never assume the companion is visible: check `status()` —
   `suppressed: true` (lock, fullscreen, game mode, area picker) or
   `enabled: false` means the user cannot see it.
4. `play` one-shots an animation without disturbing the behavior
   state; `setState` changes the state. Use `play` for reactions,
   `setState` for modes.
