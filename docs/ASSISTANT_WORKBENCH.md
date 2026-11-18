# Javi's Workbench: audit and contract

Status: implemented in this repo (shell) and HorneroOS/hornero (typed stream
frames). Sources: `modules/companion/{AssistantBridge,ChatPanel,ApprovalCard,WorkbenchPane}.qml`,
`services/{AssistantRun.qml,assistantrun.js,AssistantCopy.qml,assistantcopy.js,InlineAsk.qml,inlineask.js}`,
`docs/COMPANION_ASSISTANT.md`, `docs/adr/002-companion-assistant-boundary.md`,
and in HorneroOS/hornero `docs/javi-secure-harness.md` plus
`cli/modules/hornero_core/assistant*.v`.

The assistant is optional and off by default. Everything below is a view over
`horneroctl assistant ...`; the shell never talks to Hermes, never holds the
gateway key and never decides policy.

## 1. Audit: what exists

| Capability | Backend (horneroctl / Hermes) | Shell | Notes |
| --- | --- | --- | --- |
| Streaming answer | `ask --json --stream` NDJSON `delta` frames + final CommandResult | `AssistantBridge` -> `AssistantRun` | live text, capped |
| Activity trace | `thinking`/`tool`/`commentary` frames from `assistant_event_trace` | timeline in Workbench, trace toggle in panel | gateway-emitted activity, not raw reasoning |
| Sessions | `sessions`/`sessions new\|use`, continuity key per session and workspace | session bar, History tab | Hermes owns conversations; shell keeps a capped presentation cache |
| Modes Ask/Agent/Chat | `ask --mode` + session mode; Ask read-only and auto-denies approvals, Chat no authority; escalation guard | mode buttons (panel + Workbench), inline ask uses `--mode ask` | gateway has no per-run tool suppression: horneroctl stops a run that runs tools in Ask/Chat (documented residual) |
| Attachments | `--attach` (allowlist, caps, secret-path refusal) | paperclip, chips, Artifacts tab | the backend lists no agent-created files |
| Voice notes | audio attachment, Hermes transcribes | explicit mic, elapsed time, discard, 2 min cap, file removed after the run | no ambient mic, no wake word, no TTS (not backed) |
| Approvals | `approval.request` -> `approve <run-id> approve\|deny` (maps to gateway `once`, never session/always); policy ABAC, capability broker, audit log | `ApprovalCard` | one decision, one action |
| Clarifications | `clarify.request` -> `clarify <run> <text>` | clarify card | |
| Stop | `stop <run>` | Stop button, IPC `askStop` | server-side |
| Model | `model show\|list\|set` | model/provider line, explicit Apply (Workbench) | Control Center keeps the full picker |
| Isolation | `gateway status` reports `bubblewrap` vs `systemd-only (not sandboxed)` | shown on the approval card, Control Center, banner | never claimed when not reported |
| Policy, workspaces, prompt, audit log | `policy`, `workspace`, `prompt`, `log` | Control Center Javi pane | unchanged |
| Quick ask | same `ask` | launcher `>ai` | |

### Findings fixed by this work

1. **Pending approvals never reached the UI.** `fail_result` dropped `data`, so
   the final line of a blocked run had no `runId`/`pending`/`detail`. The panel's
   approval card could not appear from the real stream. Pending/denied results
   now keep `runId`, `pending`, `detail` (redacted), `choices`, `mode`
   (`fail_result_data`).
2. **Stop did not know the run id while streaming.** The id only arrived with the
   final line, so Stop during a long run stopped the local process only. The
   stream now opens with a typed `run` frame.
3. **A blocking request was invisible until the stream ended.** `approval` and
   `clarify` frames are now emitted the moment the event arrives.
4. **Stale approvals.** The event log keeps every `approval.request`; following a
   run after the user approved re-reported the old request. Approvals are now
   verified against the run status (`pending_controls`); unknown status keeps the
   event-based answer, so a real request is never hidden.
5. **Quick ask was not read-only.** `InlineAsk` documented a `--mode` gap that no
   longer exists; it now runs `--mode ask` and fails closed on an old horneroctl.
6. **`currentModel` was the first model in the list**, not the configured model;
   it now comes from `model show`.
7. Constant full-card scanlines (160 rectangles) removed from the panel.

### Still missing (not faked)

- A backend list of pending runs (restart recovery verifies one saved run id).
- Per-run tool suppression at the gateway (`run_mode` capability).
- Agent-created artifacts listing, usage/cost per run, TTS, wake word.
- Kernel egress filtering (documented residual in the secure-harness doc).
- A capability/risk rating for approvals: Hermes sends the exact (redacted)
  request and nothing else, so the card shows that text, the last tool the
  gateway reported, mode, workspace and isolation, and says it cannot rate risk.

## 2. Event contract

### 2.1 Wire frames (horneroctl -> shell)

`horneroctl assistant ask` or `events` with `--json --stream` writes one JSON object
per line. A frame with a string `type` is typed; the final CommandResult has a
boolean `ok` and no stream `type`.

| `type` | Payload | Meaning |
| --- | --- | --- |
| `run` | `text` = run id | the run exists; first frame of `ask` |
| `delta` | `text` | answer text |
| `thinking` | `text` | provider reasoning preview (`tool.progress` `_thinking`) |
| `tool` | `text` | `▸ name[: preview]` started, `✓ name` ok, `✗ name` failed, `name: delta` progress |
| `commentary` | `text` | mid-turn note (`assistant.commentary`) |
| `approval` | `text` = redacted request | the gateway asks for a decision |
| `clarify` | `text` = question | the gateway asks a question |
| (final) | `ok`, `message`, `data{runId,pending,detail,choices,mode,text}` | result; `pending` is `approval`, `clarify`, `denied-by-mode` or `none` |

Unknown typed frames are ignored (forward compatible). A process that exits
without a final line is a disconnect, never a success.

### 2.2 Canonical state: `AssistantRun`

One run state per shell, owned by `services/assistantrun.js` (pure, node-tested)
and exposed by the `AssistantRun` singleton. Every surface reads it; only
`AssistantBridge`, the single owner of the horneroctl processes, writes it.

Domains and their single source:

| Domain | Source of truth |
| --- | --- |
| run (phase, run id, text, timeline, pending) | `AssistantRun.run` |
| gateway (enabled, reachable, compatible, isolation, workspace) | `AssistantRun.gateway` from `assistant status` |
| conversation cache | `AssistantBridge.history` (presentation only) |
| sessions / model | horneroctl registry and Hermes config, read via verbs |
| companion pose | `CompanionStore` (driven by intents, never the reverse) |

Phases: `idle`, `starting`, `streaming`, `awaiting-approval`,
`awaiting-clarification`, `cancelling`, `completed`, `failed`, `cancelled`,
`disconnected`, `blocked`.

Status key shown to the user (`AssistantRun.status`): `disabled`,
`disconnected` (or `reconnecting` while probing), `degraded` (incompatible
gateway), `degraded-isolation` (connected, not sandboxed), `connected`,
`running`, `awaiting-approval`, `awaiting-clarification`, `blocked`, `failed`.
Run problems and pending decisions outrank a calm "connected"; a disconnected
gateway outranks everything.

Race, cancel, restart:

- Every process start gets a generation (`seq`). Lines and exits carry it; a
  stale generation is dropped, so a cancelled run's late output cannot touch a
  newer run.
- Cancel sets `cancelling`; the exit settles to `cancelled` regardless of the
  exit code. The server-side stop uses the run id from the `run` frame.
- Exit without a final line: `disconnected`, running tools become `unknown`,
  no activity stays "running" (no stale activity after death).
- Exit while a request is pending: the request stays answerable (the run waits
  server-side) and is marked "stream closed".
- Trace lines never clear a pending request; answer text after it does (the run
  moved on, e.g. decided from the CLI).
- A decision must name the run that is waiting; a stale card or IPC call cannot
  decide another run. Decisions are single-flight.
- Restart: while a request is pending a small snapshot (run id, kind, redacted
  detail) is written under `$XDG_STATE_HOME/hornero/companion/pending-request.json`
  and verified on the next start with `assistant events <run>`, which checks the
  run status. A finished, decided or expired request is dropped, never shown.

### 2.3 Presentation intents (shell -> companion)

The reducer emits cosmetic intents; `AssistantBridge` forwards them as
`CompanionStore.requestState(...)` (and the reaction bus consumes the same
intents). Consecutive identical states are not re-announced.

| Intent | Companion state | When |
| --- | --- | --- |
| `thinking` | `thinking` | run starting, reasoning, decision accepted |
| `speaking` | `thinking` | answer text streaming (mapped to thinking until a dedicated pose exists) |
| `acting` | `acting` | a tool is running |
| `attention` | `warning` | a decision/question is waiting, or a tool failed |
| `success` | `success` | run completed |
| `denied` | `denied` | blocked by mode, or the user denied |
| `error` | `error` | failed or disconnected |
| `rest` | `idle` | reset or cancelled |
| `listening` | `listening` | microphone open (set by the bridge) |

Animations never encode permissions: `attention` means "something needs you",
not "approved", and no intent exists for approval. Approval and denial are
only ever user actions on the card.

## 3. Surfaces: one engine, three levels

- **A. Quick (Javi Radio and the launcher `>ai`)**: one shared `InlineAsk`,
  `--mode ask`, nothing persisted, each surface cancels only its own run
  (`InlineAsk.owner` + `generation`). If the gateway asks for a decision or a
  tool is blocked, horneroctl denies it by mode or the run is stopped (a
  stop, never an approval), and Radio / the row offers "Open the Workbench".
  A quick question never escalates silently.
- **B. Conversation panel**: streaming, markdown, copy, retry, stop, sessions,
  model line, attachments, mic with status and discard, live trace, errors,
  connection banner with Reconnect.
- **C. Workbench**: the same panel expanded (`qs ipc call companion workbench`,
  `workbenchDraft <text>`, which only stages text, or the expand button). Tabs: Activity timeline, Approvals (pending card and
  decisions this session), Artifacts (files you attached; the backend lists no
  agent files), History (sessions, clear, retention). Model and mode controls.
  A new pending approval opens the Approvals tab itself.

### Hand-off from a quick question

Pressing "Open the Workbench" in Javi Radio (or "Continue in Workbench" on
the launcher row) opens the Workbench on the Approvals tab with a hand-off
card (`HandoffCard.qml`, `AssistantRun.handoffRecord`): where it came from,
the question, and the exact request the quick run ran into (plain text,
hidden characters made visible). The quick run was read-only, so the card
has no Allow button: horneroctl already denied that approval (and refuses
to approve any non-agent run), and the shell keeps it out of the pending
state. The card offers **Run as Agent** (a new Agent run of the same
question; its approvals arrive on the normal card, bound to the exact
request), **Edit first** (stage the question in the input) and **Dismiss**.
A hand-off never replaces a live run or a pending decision.

Entry points: Javi Radio (`javiradio` IPC, its shortcut, launcher action,
Javi/nest click, bar item; see `docs/JAVI_RADIO.md`), the launcher `>ai`
route, the nest's "workbench" click action, and the Workbench IPC. A bar
module and a PluginKit action can use only these entry points (open UI,
stage text, read-only ask); there is no IPC to approve, deny or answer
anything.

## 4. Approval UX rules

The card shows: the exact redacted request in a monospace well, run id, last
tool reported by the gateway, mode, workspace, isolation (never "sandboxed"
unless the backend said `bubblewrap`), scope ("this one action, once"), and an
honest risk line (Javi cannot rate it). Buttons are Deny and "Allow once" with
equal weight, neither focused by default, disabled while a decision is in
flight. No "approve all", no remember, no auto-approve, no timer. Allow is
enabled only for an Agent run (the run's recorded mode), with a bound
request id and the whole request on screen; the bridge re-checks all three. In Ask and Chat modes an approval event is denied by horneroctl
without showing a card, whatever the run status says; the mode is the
RUN's mode, recorded server-side by run id (an unknown run is treated
as read-only).

## 5. Security notes

- No secrets in QML: the shell reads status/model/session through horneroctl;
  detail strings are redacted in horneroctl before they reach the shell.
- No silent screenshot or clipboard: copy is an explicit button; screenshots
  exist only as a broker tool behind approval.
- No ambient microphone: opened only by click, visible state, discard, 2 min
  cap, file deleted after the run.
- No workspace content to providers without the user's explicit attachment or
  an approved tool call.
- The quick surface cannot approve or act.
- Residuals: see `HorneroOS/hornero docs/javi-secure-harness.md` (shared
  network namespace, same-UID loopback key, gateway-side mode suppression).

## 6. Customisation

Defaults are the safe ones; the user can change them in Control Center > Javi:
chat mode, history retention, streaming, assistant on/off, model, workspace,
policy preset. Language of the microcopy follows the system locale (ES or EN).

## 7. Tests

- `tests/test_assistant_run.py`: node-executed reducer (frames, races, cancel,
  disconnect, pending, status).
- `tests/test_assistant_copy.py`: ES and EN stay in sync, concise, not slangy.
- `tests/test_launcher_inline_ai.py`, `tests/test_javi_chat.py`,
  `tests/test_companion_runtime.py`: static contracts.
- `tests/fixtures/fake-horneroctl.py`: scripted horneroctl for scenario runs
  (used by the VM evidence). hornero: `assistant_contract_test.v`.
