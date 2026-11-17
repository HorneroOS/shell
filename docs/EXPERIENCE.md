# Experience modes and the Signal instrument deck

Experience modes (RFC 0001 §5a, Signal Visual Language §13) change density,
motion, glow, notification policy and the desktop layer; they never replace
the layout preset or the theme. The profiles live in
`services/experience.js`, the active mode in
`$XDG_STATE_HOME/hornero/experience.json`, per-mode customisations in
`shell.json` `experience.modes`. Control Center › Experience and
`qs ipc call experience …` ([IPC.md](IPC.md)) are the two ways to change
them.

## Desktop layer per mode

| Mode | `desktopWidgets` | What is on the desktop |
|------|------------------|------------------------|
| Focus | `none` | nothing; no widget is instantiated |
| Everyday | `user` | the desktop widgets the person enabled in Extensions |
| Signal | `instruments` | the curated instrument deck (below) |
| Gaming | `none` | nothing; widgets unload and release their provider leases, so the desktop costs no CPU or GPU under a game |
| Studio | `user` | the person's own widgets |

`desktopWidgets` is a per-mode field: a person can choose `user` for Signal
or `instruments` for Studio in the Experience pane and the rest follows.

## What Gaming and Focus guarantee under a fullscreen window

The policy is one pure function (`policy()` in `services/experience.js`)
that `services/Experience.qml` binds to, so it is tested as behaviour
(`tests/test_experience.py`) and not as source text.

| Behaviour | Gaming | Focus | Everyday |
|-----------|--------|-------|----------|
| Popups held (filed in the notification centre, counted, reported on leaving) | always | always | never |
| Critical notifications | still shown | still shown | shown |
| Telemetry polling (SystemUsage, NetworkUsage, PluginKit providers) | paused while a window is fullscreen on the focused output | same | continues |
| Desktop widgets and clock | none; also hidden under fullscreen | none | the person's own |
| Idle inhibit | while fullscreen | off | off |
| Motion, glow, scanlines | off, not overridable | glow/scanlines off | standard |

Fullscreen detection reads the compositor's window state as a bit set
(`fullscreen & 2`), so a window that is both maximised and fullscreen
counts. Only Hyprland reports it; on Niri nothing is detected and these
rules do not trigger. A borderless window that merely fills the output is
a normal window to the compositor and is not treated as fullscreen.

The Drawers window drops its input regions, closes every drawer and
disables the bar while a window is fullscreen on that screen
(`tests/test_gaming_focus_contract.py`), and no surface other than the
ones the person opens on purpose (area picker, companion chat) requests
exclusive keyboard focus. Whether a given game also behaves (focus,
tearing, controller) is a property of the game, Proton and the compositor;
the live check is the QA scenario `experience/gaming-fullscreen`.

## The Signal instrument deck

Signal is where the richest telemetry lives, so it composes a deck of
PluginKit desktop widgets instead of just styling the Everyday desktop:

| Priority | Widget | Rail |
|----------|--------|------|
| 1 | System Insight (`hornero-system-insight`) | right, top |
| 2 | Network Scope (`hornero-network-scope`) | left, top |
| 3 | Audio Deck (`hornero-audio-deck`) | left, bottom |
| 4 | Calendar (`hornero-calendar`) | right, top |
| 5 | Agenda (`hornero-agenda`) | right, bottom |
| 6 | Moon Phase (`hornero-moon-phase`) | left, bottom |

How it is laid out (`services/deck.js`, executed headless in
`tests/test_signal_deck.py`):

- Per display, in logical pixels, inside the widget area the desktop layer
  already insets for the bar edge and shell margin, so the deck never covers
  a bar. The desktop clock's box is passed as a reserved zone and is kept
  clear.
- Two rails on the flanks; the middle (480 px, or 30 % of a narrow display) stays open for
  windows and the wallpaper. Widgets take the preferred rail, then the other
  one, shrinking toward their manifest minimums when space is short.
- What does not fit is dropped by priority, never overlapped. A 1366×768
  display shows four instruments; a 3440-wide ultrawide shows all six
  (`.github/evidence/signal-deck/deck-layout.png`, a layout diagram, not a
  render).
- Every display is solved independently, so mixed resolutions and scales
  each get a deck that fits.
- Each module is the PluginKit desktop frame: panel fill, hairline border,
  `NN · TITLE` channel eyebrow and registration marks at the corners.
- Entering uses the shared motion primitives (`Choreography.rowDelay`
  stagger, `scanTravel`, `FadeAnim`); at motion level `off` they appear at
  once. Leaving the mode fades the deck layer out before the widgets unload.
- Glow is drawn only by traces that lease the shell-wide budget
  (`Experience.acquireGlow`: three items in total, 4 px, 40 % alpha, static)
  and only while `Experience.glow` holds. The budget is shared by the native
  instruments (on-air bar, dashboard scopes) and the extensions' traces;
  extensions never take the last slot, so the shell's own instruments always
  have one. A trace without a lease renders the same line without the halo.
  The deck frame itself draws no glow.

### Extensions that are not there

The deck loads the six curated extensions from the installed first-party
packages whose payload is trusted (`official`, `trusted` or `signed`). It does
not enable them in Extensions and never writes lifecycle state; Everyday
shows a widget only when the person enabled it. A package that is missing,
untrusted, failed or blocked by safe mode is simply absent from the deck, and
the Experience pane lists it as "not installed", "not trusted", "failed to
load" or "safe mode". A widget that has no room on a small display is dropped
and not drawn, never overlapped.

### Overrides and reset

- **Desktop widgets manager** (Control Center › Experience › Desktop widgets;
  the one home for the deck, so Extensions only installs, enables and trusts
  packages and links back here). Per mode it offers: an **Edit desktop**
  button (same edit mode as `qs ipc call plugins editDesktop`: drag, corner
  resize, 8 px grid) and **Reset layout**; a **desktop map** that runs the real
  solver on a 1920x1080 reference display so every switch shows its effect
  (it loads no extension, holds no provider lease and shows no telemetry);
  per widget a switch, side/stack-end **anchor**, **order** (placement
  priority), **size** (small 0.85x, normal, large 1.2x of the default frame),
  frame **opacity** (100/85/70/50 %; High Contrast forces opaque), **accent**
  (plain, signal, cue) and **density** (compact, cozy, roomy padding), and a
  **Settings** button that opens the extension's own typed settings in
  Extensions. **Presets**: built-in (Everything, Cozy corner, Kawaii night,
  System monitor, Time and sky, System Insight only) and up to five saved per
  mode. Stored in `shell.json` under `experience.deck`
  (`hidden`, `geometry`, `anchors`, `order`, `style`, `presets`, all per mode,
  all validated and written only when different from the factory). A widget
  switched off is unloaded and releases its provider leases. Anchors yield to
  a hand-placed position; the solver still never covers the bar or reserved
  zones. Reduced motion: the map's tile moves are instant.
- Turn a widget off per mode: Control Center › Experience › Desktop widgets, or
  `qs ipc call experience setDeckHidden signal hornero-agenda true`.
- Move or resize: `qs ipc call plugins editDesktop` (drag, 8 px grid). While
  the deck is showing, geometry is stored per mode and per display under
  `shell.json` `experience.deck.geometry.<mode>.<screen>`, never in the
  Everyday layout (`plugins.desktopWidgets`).
- Overrides survive mode switches, restarts and the reset of other modes.
- Reset: "Restore deck" in the edit toolbar (this display),
  "Reset deck" in the pane, `qs ipc call experience resetDeck signal`, or
  "Reset customisations" for the mode (also clears the deck).

## Idle-CPU measurement

The deck must stay cheap. `scripts/perf-signal-deck.sh` samples the running
shell in each mode with the existing baseline harness
(`scripts/perf-baseline.sh`, see [PERF_BASELINE.md](PERF_BASELINE.md)) and
prints one comparison table. It switches modes through the shell's own IPC, so
run it only in a disposable session, never on a real desktop.

QA VM run (one VM at a time, machine-wide):

```bash
flock ~/.local/share/hornero-signal-mission/vm.lock \
  uv run hornero-qa run experience/mode-signal --mem-mb 3072   # boots the guest
# inside the guest, with the checkout at /opt/hornero-shell (or similar):
HORNERO_DISPOSABLE_SESSION=1 ./scripts/perf-signal-deck.sh --samples 8 --interval 2
```

Acceptance: Gaming adds nothing over a bare desktop (`cpu_percent` equal
within noise, deck widgets unloaded); Signal's idle `cpu_percent` is reported
next to Everyday so a regression is visible. Numbers are point-in-time
observations for comparison, never published estimates.

## Mode chrome (shell#511)

Each mode wears its own bar chrome so a mode switch is visible at a glance,
not only through the mode chip. Fields (all per mode, customisable in
Control Center > Experience, documented in [IPC.md](IPC.md)):
`chrome.accent`, `chrome.edge`, `chrome.wash`, plus the existing `scanlines`
and `glow`. Factory values: Focus ink hairline; Everyday none; Signal amber
glowing edge, 7 % wash and scanlines; Gaming cue hairline; Studio phosphor
hairline with a 4 % wash. The glow edge falls back to a hairline when glow
is gated off (day theme, reduced motion, High Contrast, glow budget); High
Contrast drops the wash. Clear bars have no slab and skip the chrome.

### Layout and scale QA (offscreen)

`tests/qa_matrix/` renders the real bar for every preset. Run on 2026-11-17
(144 renders: 16 layouts x 5 viewports in Signal, plus 5 modes at 1920x1080@1.25):
zero overlapping entries, zero entries off-screen, zero items wider than
their slot. `tests/placement/matrix.test.mjs` sweeps the anchored-surface
solver (16 presets x 5 screens x 2 UI scales x triggers x 4 sizes, 5320
cases): no surface leaves the usable area or covers its trigger.
Not covered: real multi-monitor mixed scale (one offscreen screen), popups
rendered in QML, glow halo (layer effects are stubbed offscreen).

### Measured cost (offscreen, software raster, development host)

Cockpit at 1920x1080@1.25, whole 6 s harness run including startup, three
runs each: Everyday 2.2-2.3 CPU-s, Signal 2.6 CPU-s, Gaming 2.2 CPU-s;
peak RSS about 230 MB in all modes. Signal's chrome (scanline texture on
two slabs) costs about 0.4 CPU-s per run in this setup. These are not idle
CPU or frame-time numbers of a live GPU session; those remain unmeasured
here (see PERF_BASELINE.md for the existing probes).
