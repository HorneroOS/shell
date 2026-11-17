# Companion

The Companion is the Hornero sidekick: a small skinned bird that idles,
ambles, flies, and greets across shell surfaces. This page documents the
production asset pipeline, not a mockup.

## Vocabulary (default skin first)

| Animation | Frames | Timing | Loop | Next | Anchor |
| --------- | ------ | ------ | ---- | ---- | ------ |
| `idle` | idle | 900 ms | yes | idle | feet |
| `walk` | walk, idle | 320 ms | yes | idle | feet |
| `fly` | fly | 500 ms | yes | idle | center |
| `greet` | walk | 650 ms | no | idle | feet |

Poses: `idle` (standing, wings folded), `fly` (airborne, wings raised),
`walk` (standing, wing raised, beak open; doubles as the greet key).

## Skins and fallback

`default` (Hornero, no clothing) ships the full vocabulary. The four
skins — `argentina`, `blue-gold`, `red`, `gaucho` — ship grounded poses
(`idle`, `walk`, `greet`) only; their `fly` resolves to the default fly
frame through the explicit per-skin `fallbackChain` (`[skin, default]`)
in `assets/companion/manifest.json`. Unknown skins/animations resolve to
default/idle and never fail.

Assistant states map to default-skin animations: `resting` → idle,
`listening` → greet, `thinking` → walk, `speaking` → fly.

## Normalization

Every frame is a 512x512 RGBA canvas, content fit to 448 px, real
transparency (no baked checkerboard, labels, or numbers):

- Grounded poses (`idle`, `walk`): feet baseline at canvas y = 472,
  horizontally centered (anchor `feet`).
- `fly`: content centered on (256, 256) (anchor `center`).

`manifest.json` (`manifestVersion: 1`) records per animation `id`,
`frames` (file, `size`, `offset`, `anchorPx`), `frameMs` timing, `loop`,
`next`, and `anchor`, plus canvas, baseline, skins, fallback chains,
and assistant states.

## Regenerating

```sh
scripts/derive-companion-assets.py            # slices sources, writes frames + manifest
scripts/preview-companion-assets              # writes assets/companion/preview/*.png
scripts/derive-companion-assets.py --check    # drift gate (also run by tests)
scripts/preview-companion-assets --check      # sheet drift gate
```

`preview/` holds three deterministic contact sheets committed for
review: `preview-default-animations.png`, `preview-skins.png`
(fallback cells tagged), `preview-assistant-states.png`. Source
provenance, hashes, and hand-traced seams live in
`assets/companion/SOURCES.md`.

## Consuming from QML

```qml
import qs.modules.companion

Image {
    source: Qt.resolvedUrl(Companion.frameSource("argentina", "walk"))
}
```

`Companion.resolve(skin, animation)` returns file, anchor, anchorPx,
frameMs, loop, next, and whether the frame fell back. A missing or
malformed manifest degrades to the default idle frame; UI should hide
the sprite until `Companion.ready`. `Companion.reel(skin, animation)`
returns the full frame-file list plus timing/loop/next for the
animation player, with the same fallback rules.

## Runtime

`modules/companion/` hosts exactly one companion (`CompanionHost`,
wired in `shell.qml`):

- `Player.qml` — reusable frame player on a single `Timer` core
  (timing, loop, `finished()`, fallback frame, pause). Single-frame
  reels never run the timer, so an idling companion costs nothing.
- `CompanionStore.qml` — behavior state machine plus persisted
  settings and position (`PersistentProperties`, id `companion`):
  `hidden`/`peeking`/`entering`/`idle`/`hovering`/`talking`/
  `excited`/`dragging`/`leaving`/`sleeping`, with the future
  assistant states (`listening`/`thinking`/`acting`/`success`/
  `warning`/`error`) accepted and mapped to animations only —
  reserved for a future assistant daemon, with no backend behind
  them today (see `docs/COMPANION_ASSISTANT.md` and
  `docs/adr/002-companion-assistant-boundary.md`).
- `CompanionHost.qml` — the overlay: hybrid frames-plus-transforms
  (idle bob, takeoff/fly/landing, landing bounce), drag with
  monitor-aware persisted position (screen-relative fractions plus
  monitor name, following the focused monitor when unplaced),
  speech bubble, right-click menu (tip / skin / reset / hide /
  settings), edge-summon peek/fly-in, and sleep after a long idle
  (default 10 min, any interaction wakes).
- `Bubble.qml` — wrapping text, 240 px max width, edge flipping,
  timed dismissal, `dark`/`light`/`pampa` themes (`auto` follows the
  shell theme).

Living-companion reboot: at idle, a weighted scheduler
(`IdleScheduler.qml`) plays occasional one-shots (blink, look,
preen, stretch, hop, chirp, carry-a-twig) without ever interrupting
task states. Relocation flights are opt-in (`wanderEnabled`, off by
default — the companion otherwise stays exactly where you put it).
Carry trips progressively build the nest prop (twigs → cup → dome →
home, persisted as `nestStage`); `sleepAtNest` flies home before
sleeping. Activity cadence is `activityLevel` (calm/normal/lively).

Suppression (all automatic): session lock, fullscreen windows, game
mode, the area picker, and any open Settings window hide the
companion; disabling it in settings unloads every surface and timer
(zero cost). The window is a `Bottom`-layer, `Ignore`-exclusion
surface with no keyboard focus sized to the sprite, so it never
steals clicks or input. Reduced motion holds still frames and
replaces bob/bounce/fly transitions with jump cuts.

Character bible (visual reboot, refined): the original painterly
rufous hornero stays the reference — single visible eye in 3/4
profile facing right (mirror is runtime), cream belly vs russet
back, feathered wing/tail detail, warm and organic, never a flat
geometric mascot. New life poses are AI-generated keyframes
art-directed from the original frames (`assets/companion/sources/
poses/`, chroma-keyed by the derive pipeline) plus procedural
in-betweens from `scripts/companion_poses.py`. Garment skins keep
their painted identity frames and fall back to the default bird
for the new animations; palette skins are recolors of the same
generated poses.

## Reactions to real events

Javi reacts to things that actually happened, never on a timer. The
policy is `modules/companion/reactions.js` (pure, tested under node);
`CompanionReactions.qml` is the single bus and
`CompanionStore.playReaction()` shows the beat.

| Kind | Source | Priority | Animation | Bubble |
| ---- | ------ | -------- | --------- | ------ |
| `notification` | Notifs (a popup was shown; not duplicates, not held by DND/mode) | 1 | look | none |
| `battery.low` / `battery.critical` | BatteryMonitor warn levels | 2 / 3 | worry | yes |
| `charger.plugged` / `charger.unplugged` | UPower | 1 | approve / look | none |
| `mode.changed` | Experience (not the first state load) | 1 | blink | none |
| `build.done` / `build.failed` | IPC or PluginKit only | 2 | celebrate / worry | yes |
| `download.done`, `device.connected`, `device.disconnected`, `task.done`, `attention` | IPC or PluginKit only | 1-2 | approve / look / hop | optional |

There is no native build, download or device emitter yet: those kinds
exist for IPC (`qs ipc call companion react build.done "text"`) and
extensions, and Javi never invents them. Native-only kinds (battery,
charger, notification, mode) cannot be raised from IPC or a plugin.

Behaviour levels per Experience mode: `full` (every enabled kind, with
bubbles), `quiet` (priority 3 only, animation only, never a bubble),
`silent` (nothing). Defaults: Everyday full, Signal full, Focus quiet,
Studio quiet, Gaming silent (the companion is also hidden in game mode
and over fullscreen windows). Quiet hours (default 22:00-07:00, off)
downgrade `full` to `quiet`; they never loosen a mode. Cooldowns are per
kind; at most 6 non-critical reactions per 5 minutes; an extension gets
3 per minute and can be muted per source. A reaction never interrupts a
task state (listening/thinking/dragging...) or wakes a sleeping
companion unless the event is priority 3. External text is plain,
single-line and capped at 80 characters. Reduced motion still shows the
bubble; the animation holds a still frame.

## Z-order policy

The companion is ambient chrome, not a window citizen: it lives on
the layer-shell `Bottom` layer, above the wallpaper but below ordinary
windows and shell panels. This keeps it visible on the desktop while
ensuring open windows, drawers and pickers remain unobstructed. It never
steals focus, and returns to its persisted position after a configuration
surface closes. Settings (a regular floating window) and the area picker
explicitly suppress it while open through
`CompanionStore.controlCenterOpen` and `areaPickerOpen`, respectively.
There is no per-window z-order juggling or click-through exception.

Control Center › Companion exposes enable, character, size,
idle-to-sleep, tips, edge, bubble theme, summon, and position reset.
Everything is also adjustable over IPC (`qs ipc call companion …`):
`summon`/`hide`/`toggle`/`say`/`tip`/`play`/`setState`/`setSkin`/
`resetPosition`/`status` — see `docs/IPC.md`. (`summon`, not `show`: an
IPC function literally named `show` is unreachable through
`qs ipc call` — the token is swallowed as the `ipc show` subcommand.)
