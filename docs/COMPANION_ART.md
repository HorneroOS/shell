# Javi: character bible, master-art brief and ingestion spec

Character art direction is separate from animation engineering. This page
is the contract for any master artwork (hand painted, externally generated,
or vector). The pipeline accepts raster masters as first-class input; see
"Ingestion".

## Species reference (Furnarius rufus, rufous hornero)

Sources read (text only; no photos are copied into the repository):
Wikipedia (en, es) species articles. Cornell/eBird and Aves Argentinas
pages blocked automated access, so colour hex values below are art
decisions informed by those descriptions, not measurements.

- Length 16-23 cm, 31-65 g; sexes alike.
- Bill slender, slightly decurved, about 2.5 cm, dark horn grey. It is
  medium length, not kiwi-like: aim for a bill about as long as the head is
  wide.
- Crown dull greyish-brown, forehead reddish-brown, a faint pale
  supercilium, paler lores. Back rufous-brown. Throat whitish. Breast pale
  brown, belly paler and brighter.
- Wings mostly rufous; flight feathers blackish; secondaries pale brown;
  cinnamon wingbar. Tail rufous, short and square.
- Legs dark grey to grey-pink. Walks and trots on the ground; short flights;
  upright, alert stance, round head, no crest.
- Nest: a clay "oven" of mud and plant fibre; entrance to one side with an
  inner baffle; about 5 kg. A pair often repeats the same side.

What current Javi gets wrong: wren-like cocked tail, tufted crown (crest-like
in `hop`), russet legs, throat not clearly paler, bill too short, rounded
"songbird" silhouette. These make him read as a wren or sparrow.

## Character bible

- Identity: a calm, curious, slightly proud ground-walker. Upright, round
  head, steady eye, clean neat plumage. Warm and organic: painterly, never a
  flat geometric mascot, never a robot.
- Proportions (head width = 1): body length 2.6, body height 2.2, bill 1.0,
  tail 0.9 (short, square, held low, never cocked), legs visible 1.1, eye
  diameter 0.2 placed just above the bill line, single eye in 3/4 profile
  facing right (mirrored at runtime).
- Colour (hex): crown #8C5A3C, forehead and back #A4562A, back light
  #C9783C, back shadow #6E3519, throat #F3E6D2, breast #D8B48A, belly
  #E8CFA6, tail #B5602C, flight feathers #3A2A22, wingbar #D98A4C, legs
  #B09A8C, bill #6B5B50, eye #1B110D.
- Light: warm amber from the right (workshop), faint cyan phosphor from a
  tiny CRT when thinking. Rim light only; no coloured anatomy.
- Silhouette must read at 64-160 px: long-legged upright oval, pointed
  straight bill, short square tail, no crest.
- Do not: tufted crown, cocked tail, red legs, hat/clothing in the default
  skin, human hands, robot parts, Kiwi/Electro Andes shapes or assets.

## Master pose list (priority)

1. `idle`: standing, three-quarter right, calm.
2. `think`: same stance, leaning slightly toward a tiny CRT (0.5 head
   width glow), head tilt 10 degrees, eye lowered to the screen.
3. `sleep`: sitting in the nest mouth, head turned back, bill tucked in
   scapulars, eye closed, feathers fluffed.
Then listen, work (carrying a twig or wire), approve (small hop, wings
half open), deny, worry, error, talk, greet, walk, fly.

## Art brief for externally generated masters

Per pose, give the generator all of this:

- Subject: "a single rufous hornero (Furnarius rufus), upright, three-quarter
  view facing right, slender slightly decurved dark horn bill about as long
  as the head is wide, round head with no crest, pale supercilium, whitish
  throat, buff breast and belly, rufous-brown back, rufous short square
  tail held low, blackish flight feathers with a cinnamon wing bar, grey-pink
  legs, calm curious expression".
- Style: "painterly digital illustration, soft brush texture, warm
  storybook, clean readable silhouette, gentle rim light from the right".
- Frame: 2048x2048 PNG, transparent background (or flat #00FF00 chroma key
  with no green on the bird), bird centred, feet on y=1880, 8% margin all
  sides, no ground shadow, no text.
- Consistency: attach the approved `idle` master to every later request and
  say "same bird, same proportions, same plumage, only the pose changes".
- Negative: "wren, sparrow, finch, robin, crest, tuft, cocked tail, red
  legs, short stubby bill, kiwi bird, robot, cartoon eyes with eyelashes,
  clothing, background, text, watermark".
- `think` adds: "a tiny retro CRT monitor in front, cyan phosphor glow on
  the face, head tilted toward it". `sleep` adds: "curled in a clay oven
  nest entrance, head tucked back, eye closed, fluffed feathers".

## Ingestion

1. Put the file under `assets/companion/sources/masters/` (PNG or WebP with
   alpha, 1024-4096 px, at most 4 MiB, at least 2% transparent margin, no
   baked background).
2. Optionally defringe: `scripts/companion_masters.py --matte in out`.
3. Register it in `assets/companion/masters.json` with the sha256 pin,
   pose, anchor, pivot in master pixels, origin and, for external art,
   provenance (tool, prompt file, date, licence).
4. `scripts/companion_masters.py --check` (also run by tests) enforces the
   contract. Changing a file without updating its pin fails.
5. The derive step maps masters onto the animation vocabulary using the
   pivot; consistency of the other 24 animations is the next engineering
   step once a direction is approved.

## Candidates evaluated (2026-11-17)

Three directions were rendered for idle, think and sleep (sheets in the
mission evidence folder `javi-nest/candidates/`):

- A: hand-authored layered vector, true proportions. Correct palette and
  bill, but blobby anatomy and a stiff wing: not good enough to ship.
- B: same part library with chibi proportions. Cuter but the same weakness.
- C: current painterly frames, retouched (pale legs, whiter throat).
  Best quality, still wren-like in shape.

Verdict: procedural vector cannot reach the painterly bar. An approved
externally generated or painted `idle` master is required; nothing has been
propagated across the 25 animations.

### Candidate evaluated (2026-11-23)

- D: generated painterly model sheet and a dedicated idle master. The
  idle candidate materially improves the bill length, upright body,
  uncocked tail, dark flight feathers, wing bar and grey-pink legs,
  and remains readable at 128 px on both dark and light grounds. It
  is registered as `idle-2026-candidate` with a pinned checksum and
  generation brief. It has **not** been propagated into the shipped
  animation catalogue: `think` and `sleep` still need matching
  high-resolution masters and maintainer approval before any skin is
  rebuilt from it.

### Production rebuild (2026-11-24)

The five-pose candidate direction was extended to a full
single-pose set (greet, preen, takeoff, fly, walk, hop, stretch,
listen, perch, worry, talk, celebrate, peek, think without any
baked prop, land, sleep) and fed into
`scripts/derive-companion-assets.py` as replacement source
keyframes plus new default `orig` frames. The deterministic
pipeline regenerated every skin's frames, palette recolors and
contact previews, so identity propagates coherently instead of
mixing birds per animation. Sheet-sliced poses were rejected
during review (fragmented crops); only individually generated,
full-body poses were accepted. The `frames-hi` set is regenerated
by the same pipeline entry.
