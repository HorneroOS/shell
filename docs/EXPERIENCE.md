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

- Turn a widget off per mode: Control Center › Experience › Signal deck, or
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
