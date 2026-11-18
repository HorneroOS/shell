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

## Design note: behaviour matrix, budgets, accessibility

Audit (2026-11-17, shell main `5a32461`): the companion already ships a
painterly 25-animation vocabulary (idle, blink, look, preen, stretch,
hop, greet, walk, hover, takeoff, fly, land, perch, peek, drag, talk,
think, listen, work, approve, celebrate, deny, worry, error, sleep), 8
skins, a store state machine, an idle scheduler, IPC and a Control
Center pane. What it lacked was *context*: it never reacted to real
events and had no per-mode or quiet-hours behaviour. Reactions reuse the
existing art; no new poses were needed.

| Experience mode | Companion | Reactions (default) | Idle acting |
| --- | --- | --- | --- |
| Everyday | visible | full | per activity level |
| Signal | visible | full | per activity level |
| Focus | visible, sleeps after the idle timeout | quiet: priority 3 only, no bubble | per activity level |
| Studio | visible | quiet | per activity level |
| Gaming | hidden (game mode) | silent | none (hidden) |

Fullscreen windows, the session lock, the area picker and an open
Settings window hide the companion regardless of mode.

Budgets: the companion costs nothing when disabled (no surfaces, no
timers), nothing when hidden (the player pauses while suppressed) and
nothing while idle with a still frame; the only recurring work is the
30 s idle poll, the optional idle scheduler (one single-shot timer, 4-40 s
by activity level) and one sprite-frame timer while an animation plays.
The reaction bus has no timers of its own. Measured numbers live in the
PR evidence (visible-idle vs hidden CPU in the QA VM).

Accessibility: bubbles are plain text and dismissible; the sprite has an
accessible name; reduced motion holds still frames and uses jump cuts;
nothing flashes; reactions never move focus. Sounds are not shipped
(there is no sound engine, so there is no knob either).

Not done yet (see the PRs): looking at the cursor, perching on window
edges (both need compositor window geometry or cursor polling and a cost
review), a sound pack, and extra art (see the PR description).

## Per-mode look

Control Center › Companion › "Look per Experience mode" lets each mode
show or hide Javi, scale him (a multiplier on the global size, 0.5-2.0)
and pick its own character; "Main character" follows the global skin.
Gaming mode still hides him regardless (game-mode suppression), and an
explicit request (chat, summon) outranks a mode that hides him.

## Art needs (for the maintainer)

The engine ships with the existing painterly set; these poses would
deepen it and are the only missing art. Each must follow the
character bible above (3/4 profile facing right, rufous back, cream
belly, 512x512 canvas, feet baseline y=472) and be derived by
`scripts/derive-companion-assets.py`:

| Pose | Used for | Frames |
| ---- | -------- | ------ |
| `notify` (head tilt toward the bar) | `notification` reaction, replaces `look` | 3 |
| `celebrate-small` | `download.done`, `task.done`, quieter than `celebrate` | 3 |
| `yawn` | settling into quiet hours / Focus sleep | 4 |
| `perch-edge` | perching on a window or bar edge (needs window geometry) | 2-3 |
| `sleep` for the `nocturnal` skin | night-time sleep matching the skin | 4 |

Until then reactions reuse `look`, `approve` and `hop`, so nothing is
blocked on art.

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

## Voice and personality

Javi's small spoken lines (tips, reaction bubbles, Radio notices, nest
labels) come from one catalogue, `modules/companion/javivoice.js`, in
English and Spanish and in two tones. `JaviVoice.line(key)` is the only
way QML reads it.

- Language: `auto` follows the shell locale (`Qt.locale()`; there is no
  separate shell language override), or pin `en` / `es`.
- Tone: `warm` (default, Javi at his workbench) or `plain` (same
  information, fewer words of character).
- Rules, enforced by `tests/test_javi_voice.py`: every key exists in all
  four tables, one line of at most 72 characters, no exclamation marks, no
  emoji, no pet names, nothing that blames the user. A line decorates a
  state the UI already shows and never claims Javi thinks or feels.
- Both settings live in the validated `voice` preference document and are
  edited under Control Center, Javi, Voice. An unknown key renders as the
  key itself so a typo is visible.
- External reaction text (IPC or extensions) is never replaced by the
  catalogue; only the built-in bubbles are translated.

Preferences for voice, nest and Radio are stored as one JSON document
(`prefs`) in the companion state snapshot. Each section is re-validated by
its pure module (`javivoice.js`, `habitat.js`, `radio.js`) on every read
and on restore, so a corrupt or hand-edited file degrades per key to the
shipped defaults; a `prefs` value that is not a JSON object (`null`, an
array, a number) reads as empty and never aborts the rest of the restore.
Edits by dotted path (`patchPref`) only walk existing keys and reject
`__proto__`, `constructor` and `prototype` segments (`prefsdoc.js`).
