# Javi Radio

Javi Radio is the quick assistant: a compact panel for one short question
and one short answer, reachable from several entry points and built on the
same quick ask the launcher already uses (`services/InlineAsk.qml`, which
runs `horneroctl assistant ask --json --stream`). There is no second
session engine and no new backend path.

## Entry points

| Entry | How | Setting |
| ----- | --- | ------- |
| `shortcut` | global shortcut name `javiRadio` (suggested `Super+Shift+J`; the compositor config binds it) or `qs ipc call javiradio open` | Open Radio from, Keyboard shortcut |
| `launcher` | launcher action "Javi Radio" (`qs ipc call javiradio openFrom launcher`) | Launcher |
| `javi` | clicking Javi (default action; "Clicking Javi" can be Tip, Chat or Nothing) | Clicking Javi |
| `bar` | optional `javiRadio` bar item (add it in Control Center, Layout; in no shipped layout) | Bar item, Show Radio in the bar |
| `menu` | Javi's right-click menu | Javi's menu |
| `plugin` | `qs ipc call javiradio openFrom plugin`, for example from an extension command that declares the `qs` process | Extension actions |

Each entry has its own switch and the whole feature has a master switch
(`CompanionStore.radioSettings`, validated by `modules/companion/radio.js`).
`qs ipc call javiradio ask <entry> <text>` opens Radio from `entry` and asks
one question.

## Security contract

- Ask-only. Radio never starts an agent run, never approves or clarifies,
  never attaches files and never reads the clipboard or the screen. It
  shows plain text only.
- No silent escalation. When the final payload says `data.pending`
  (approval or clarification) or the run is blocked, Radio stops. It shows
  that the request needs approval and offers "Open the Workbench"; the
  answer is never inferred, and nothing is approved on the way.
- Extension requests (`plugin`) are not a user gesture, so they never open
  Radio in Focus or Gaming. The user's own shortcut, click, menu and
  launcher work in every mode.
- The question and answer are not logged or persisted. A closed Radio has
  no surface (it is created on open and destroyed on close).
- The companion mirrors the real state (listening, thinking, success,
  warning, error) only while visible and never wakes a hidden Javi.

## Relation to the Workbench

The Workbench (shell#622) owns the canonical run state, approvals and the
timeline. Radio is the Level A surface: when #622 lands, Radio keeps the
same entry points and the hand-off button opens the Workbench instead of
the chat panel; the policy in `radio.js` does not change.

## Not built

A PluginKit-side API call (an extension drawing a button that opens Radio
without IPC) is blocked on the governed Companion hook in shell#611/#626;
until then extensions use a declared process command. Voice input in Radio
is not offered: it needs the Workbench voice path.
