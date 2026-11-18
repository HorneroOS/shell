# Javi Radio

Javi Radio is the quick assistant: a compact panel for one short question
and one short answer, reachable from several entry points and built on the
same quick ask the launcher already uses (`services/InlineAsk.qml`, which
runs `horneroctl assistant ask --json --stream`). There is no second
session engine and no new backend path.

## Entry points

| Entry | How | Class | Setting |
| ----- | --- | ----- | ------- |
| `shortcut` | global shortcut name `javiRadio` (suggested `Super+Shift+J`; the compositor config binds it) | gesture | Keyboard shortcut |
| `launcher` | launcher action "Javi Radio" (handled in-process by the launcher, command `["javiradio"]`) | gesture | Launcher |
| `javi` | clicking Javi (default action; "Clicking Javi" can be Tip, Chat or Nothing) | gesture | Clicking Javi |
| `bar` | optional `javiRadio` bar item (add it in Control Center, Layout; in no shipped layout) | gesture | Bar item, Show Radio in the bar |
| `menu` | Javi's right-click menu | gesture | Javi's menu |
| `nest` | clicking the nest when its click action is Javi Radio (shell#634) | gesture | Clicking the nest |
| `plugin` | `qs ipc call javiradio open`, `toggle`, `openFrom <anything>` or `prefill <entry> <text>`, for example from an extension command that declares the `qs` process | IPC | Extension actions |
| `keybind` | `qs ipc call javiradio openFrom keybind`, for compositor key bindings that cannot use the global shortcut (off by default) | IPC | Compositor key binding over IPC |

Each entry has its own switch and the whole feature has a master switch
(`CompanionStore.radioSettings`, validated by `modules/companion/radio.js`).

### Trust classes

- Gestures are observed by the shell itself (the compositor delivers the
  global shortcut; the launcher, Javi, the nest, the bar item and the menu
  are clicks in shell surfaces). They open Radio in every mode, with
  keyboard focus.
- IPC cannot be authenticated: any local process can run
  `qs ipc call javiradio ...`. Every IPC call is treated as `plugin`
  whatever entry it names (it can never claim `shortcut` or `launcher`),
  except the opt-in `keybind` entry. Both IPC entries are refused in Focus,
  Gaming and under fullscreen. `plugin` opens without keyboard focus; the
  user clicks the panel to type. `keybind` takes the keyboard (that is its
  purpose), which is exactly why it is off by default: a program that can
  run `qs` can forge it. Prefer the `javiRadio` global shortcut wherever the
  compositor supports it.
- No entry point and no IPC call can send a question. `prefill` only places
  text in the input; the user reads it and presses Enter (or clears it).

### Keyboard

The panel holds the keyboard only on demand: clicking another window takes
it back (on Hyprland a focus grab also closes an idle or answered Radio; a
question still in flight keeps the panel up without the keyboard). niri
does not focus an on-demand top-layer surface opened from a shortcut, so
there the panel is exclusive while the user types and gives the keyboard
back as soon as the question finishes. Escape is handled by the panel
itself, so it works while the input is read-only during a question: it
stops the question in flight, or closes Radio. Reopening Radio always
starts empty.

## Security contract

- Ask-only on the Radio side. Radio sends one quick question through the
  same `horneroctl assistant ask` path as the launcher; the gateway may
  start a run for it, and if that run pauses for an approval or
  clarification, Radio never approves, clarifies or continues it. Radio
  never attaches files and never reads the clipboard or the screen. It
  shows plain text only.
- No silent escalation. When the final payload says `data.pending`
  (approval or clarification) or the run is blocked, Radio stops. It shows
  that the request needs approval and offers "Open the Workbench". Pressing
  it hands the pending payload (run id and what is pending) to the chat,
  which shows its approval card; the user decides there. The answer is
  never inferred, and nothing is approved on the way.
- One shared quick ask. The launcher and Radio share `InlineAsk`; each
  cancels only a run it started (`InlineAsk.owner`), and Radio checks
  `InlineAsk.generation` so a launcher question that replaced Radio's is
  reported as replaced, never shown as Radio's answer. A run that ends
  without a final payload is never treated as an answer.
- Nothing opens under a fullscreen window (the panel is on the Top layer,
  which a fullscreen window covers).
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
