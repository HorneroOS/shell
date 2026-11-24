# Javi think/sleep master candidates — generation brief

Date: 2026-11-23
Tool: Muse image generation
Status: candidates for maintainer visual approval; not propagated to
runtime frames.
Reference: the registered idle candidate sheet
(`javi-idle-candidate-2026-11-23.png` generation).

Both poses were generated as entirely new original drawings of the
same character (no tracing, inpainting or recolor of shipped frames):

- **Think:** full body, head tilted down toward a tiny retro CRT at
  its feet, faint cyan phosphor glow on face and breast, one wing
  slightly raised; flat `#00FF00` chroma background.
- **Sleep:** curled sitting pose, head turned back with bill tucked
  into the scapulars, eye closed, feathers gently fluffed; flat
  `#00FF00` chroma background, no nest or props.

Shared character constraints: Argentine rufous hornero anatomy and
the exact `docs/COMPANION_ART.md` palette, warm painterly sprite
style, readable silhouette at 128 px, no text or watermark.

Processing: deterministic chroma key with green despill, fit without
upscaling into a 1024 × 1024 canvas with the ground pivot at y=992,
then the repository `companion_masters.py --matte` defringe helper.
Reviewed at full resolution and at 128 px on dark and light grounds.
Known notes: the think pose's raised wing reads lively rather than
pensive at tiny sizes (the CRT sells the state); its screen glow
halo is intentionally keyed away, leaving only the breast tint.
