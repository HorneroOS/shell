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
the sprite until `Companion.ready`.
