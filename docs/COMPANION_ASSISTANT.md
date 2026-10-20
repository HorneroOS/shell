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
from payload data, never parsed from prose). `askStop()` now stops
the Hermes run server-side too (`assistant stop <runId>`, shell#223)
while it is known.

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
| `listening` | `greet` | perked up, wing raised — "I'm hearing you" |
| `thinking` | `walk` | mid-step pacing — "working on it" |
| `acting` | `walk` | same pacing — "doing it" |
| `success` | `greet` | cheerful greet — "done" |
| `warning` | `walk` | pacing — "heads up" |
| `error` | `walk` | pacing — "that failed" |

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
(`resting` → idle, `listening` → greet, `thinking` → walk,
`speaking` → fly), consumed via `Companion.stateSource(state)` for
static (non-overlay) surfaces. The overlay host maps the six daemon
states above instead, so both layers agree on what each state looks
like.

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
