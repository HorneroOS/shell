# Companion ↔ future Assistant mapping

The companion is presentation; the assistant will be a separate daemon
(see `docs/adr/002-companion-assistant-boundary.md`). This page is the
reserved vocabulary the daemon will drive over the `companion` IPC
target. Slice 1 now has a real backend path behind two of them:
`AssistantBridge.qml` runs `horneroctl assistant ask --json` (Hermes
Agent via horneroctl's consent and read-only allowlist), mapping
`thinking` while a run is in flight and `success`/`error` when the
answer or an honest failure line lands in the bubble. Drive it with
`qs ipc call companion ask "<prompt>"`; `askStop()` cancels locally
(the Hermes run may still finish server-side until run-id streaming
lands). Full chat UI, sessions, and approval prompts remain future
work; the assistant is disabled by default and never required.

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
