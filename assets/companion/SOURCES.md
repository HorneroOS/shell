# Companion sources — provenance

Runtime frames (`frames/`, `frames-hi/`, `manifest.json`) are derived
by `scripts/derive-companion-assets.py`. Nothing at runtime reads
outside this repository.

## Painterly keyframes (`sources/poses/`, `sources/orig/`)

The visual reboot's art direction (refined after review: the first
flat-vector pass read too abstract) keeps the original painterly
bird as the character reference. Sources:

- `sources/orig/` — the pre-reboot production frames, restored
  verbatim. Garment skins keep these painted identity frames.
- `sources/poses/` — new AI-generated key poses (green-screen,
  chroma-keyed at derive time), art-directed from the original
  frames so anatomy, palette and style match: idle, blink, listen,
  talk, think, worry, preen, stretch, walk-step, work (twig),
  celebrate, sleep, fly-down.
- `scripts/companion_poses.py` — sequences, procedural in-betweens
  (breathe/hop/tilt transforms), per-skin overrides, palette-skin
  recolors (nocturnal / retro-terminal / mono) and nest stages.

Garment skins ship their painted idle/walk/greet/talk and fall back
to the default bird for the new life animations (documented
fallbackChain), exactly like fly did before the reboot. The plates
below remain the provenance of the original set.

## Vendored plates (`sources/`)

| File | Source | Size | SHA-256 |
| ---- | ------ | ---- | ------- |
| `hornero-default.png` | Artist plate (1), default Hornero, no clothing | 1448x1086 RGBA | `0508514951455ee5e43ab0bfe2c478d25d09502cec6266cc90ae23d178777d27` |
| `skin-argentina.png` | Artist plate (2), light-blue/white stripe jersey | 1448x1086 RGBA | `2d7314cb36057f70de795779c896dc1064c4e8c5576f32b1789f2ba972d6a1e6` |
| `skin-blue-gold.png` | Artist plate (3), blue/yellow V-neck | 1448x1086 RGBA | `a93cd49cb3ded97fa8f8059160430b7d21c729eecca3b2d0d9990987f19ae709` |
| `skin-red.png` | Artist plate (4), red/white-trim | 1448x1086 RGBA | `ebcb886d23579921e4427ec7dce3baec402215c784d5cc8cee7b0e33c56ea79d` |
| `skin-gaucho.png` | Artist plate (5), boina + poncho + neckerchief | 1448x1086 RGBA | `35bc934b7e6478e6983d25b8c70cea10a1e47f45e0d470f001f6134811e41c3c` |

All five plates carry real transparency (alpha extrema 0–255, ~74% fully
transparent pixels, <0.1% fully opaque). No labels, numbers, or
checkerboard are baked into them.

## Hand-traced seams

Pose order on every plate is left-to-right: idle, fly, walk. Slice
columns (alpha-minimum, verified per plate):

| Plate | Seam idle\|fly | Seam fly\|walk | Note |
| ----- | -------------- | -------------- | ---- |
| default | 491 (true zero gap) | 985 (min, feathers touch) | clean split 1 |
| argentina | 478 (true zero gap) | 1010 (min, feathers touch) | clean split 1 |
| blue-gold | 488 (true zero gap) | 993 (min, feathers touch) | clean split 1 |
| red | 492 (min 10) | 988 (min, feathers touch) | narrow bridge at split 1 |
| gaucho | 470 (min 10) | 1009 (min, feathers touch) | narrow bridge at split 1 |

The fly\|walk seam has no fully-transparent column on any plate
(midtone feather contact, ~50–115 px tall). The cut lands on the local
minimum; frames are verified bleed-free (zero content in 24px corners
and 5px edge bands, see `tests/test_companion_assets.py`).

## Master atlas (NOT vendored)

The 1536x1024 composite (`ChatGPT Image ..., 06_09_32 PM.png`) is the
visual bible only: zero fully-transparent pixels, painted checkerboard
panels, rounded labels, and duplicated frame numbers make it unusable as
slices. It is deliberately NOT copied into this repository (no giant
atlas shipped, no baked labels/numbers/checkerboard in runtime art).

## License

New Companion QML and assets fall under GPL-3.0-only as shell runtime
per `NOTICE` (inherited from the caelestia-dots/shell import). Plates
were supplied by the HorneroOS art pass for this shell; see
`docs/COMPANION.md`.
