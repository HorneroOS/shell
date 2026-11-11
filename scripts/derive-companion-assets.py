#!/usr/bin/env python3
"""Derive Companion frames + manifest from painterly keyframes.

Pipeline (deterministic; Pillow only):
  scripts/companion_poses.py (sequences, palettes, recolors)
  assets/companion/sources/poses/*.png  (generated key poses, green screen)
  assets/companion/sources/orig/*.png   (pre-reboot production frames)
  -> chroma key / normalize / procedural in-betweens
  -> assets/companion/frames/*.png + frames-hi/ + manifest.json (v2)

Poses are authored once for the default bird; garment skins keep
their painted identity frames and fall back to the default bird for
the new life animations (documented fallbackChain).

Usage:
  scripts/derive-companion-assets.py            # write frames + manifest
  scripts/derive-companion-assets.py --check    # verify committed output
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import companion_poses as poses_mod  # noqa: E402

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover
    print("derive-companion-assets: SKIP (Pillow not installed)", file=sys.stderr)
    sys.exit(3)

ROOT = Path(__file__).resolve().parent.parent
COMPANION = ROOT / "assets" / "companion"
POSES_DIR = COMPANION / "sources" / "poses"
ORIG_DIR = COMPANION / "sources" / "orig"
FRAMES = "frames"
FRAMES_HI = "frames-hi"

CANVAS = 512
FEET_Y = 472
FLY_CENTER = (256, 256)
MANIFEST_VERSION = 2
GROUNDED_H = 430
AIRBORNE_MAX = 440
HI_ANIMS = ("idle", "greet", "fly", "perch")


def chroma_key(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            green = g - max(r, b)
            if green > 90:
                px[x, y] = (r, g, b, 0)
            elif green > 30:
                alpha = int(255 * (1 - (green - 30) / 60))
                px[x, y] = (r, min(g, max(r, b) + 20), b, alpha)
    return keep_largest(im)


def keep_largest(im: Image.Image) -> Image.Image:
    """Drop stray opaque specks (generation artifacts) by keeping only
    the largest alpha component, judged on a downscaled mask."""
    small = im.getchannel("A").resize((128, 128))
    mask = small.point(lambda v: 255 if v > 128 else 0)
    seen = [[False] * 128 for _ in range(128)]
    best = []
    data = mask.load()
    for y in range(128):
        for x in range(128):
            if data[x, y] and not seen[y][x]:
                comp, stack = [], [(x, y)]
                seen[y][x] = True
                while stack:
                    cx, cy = stack.pop()
                    comp.append((cx, cy))
                    for nx, ny in ((cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)):
                        if 0 <= nx < 128 and 0 <= ny < 128 and not seen[ny][nx] and data[nx, ny]:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
                if len(comp) > len(best):
                    best = comp
    if not best:
        return im
    keep = Image.new("L", (128, 128), 0)
    kp = keep.load()
    for x, y in best:
        kp[x, y] = 255
    keep = keep.resize(im.size, Image.NEAREST)
    alpha = im.getchannel("A")
    alpha = Image.composite(alpha, Image.new("L", im.size, 0), keep)
    im.putalpha(alpha)
    return im


def recolor(im: Image.Image, mapping: list) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            for (sr, sg, sb), (tr, tg, tb) in mapping:
                if abs(r - sr) < 46 and abs(g - sg) < 46 and abs(b - sb) < 46:
                    px[x, y] = (tr, tg, tb, a)
                    break
    return im


def paint_blink(im: Image.Image) -> Image.Image:
    """Closed eyelid over the eye of an original idle frame."""
    im = im.convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if not bbox:
        return im
    x0, y0, x1, y1 = bbox
    rx0, ry0 = x0 + int((x1 - x0) * 0.55), y0
    rx1, ry1 = x0 + int((x1 - x0) * 0.85), y0 + int((y1 - y0) * 0.45)
    px = im.load()
    dark = [(x, y) for y in range(ry0, ry1) for x in range(rx0, rx1)
            if px[x, y][3] > 200 and sum(px[x, y][:3]) < 150]
    if len(dark) < 12:
        return im
    cx = sum(p[0] for p in dark) // len(dark)
    cy = sum(p[1] for p in dark) // len(dark)
    r = max(6, int((max(p[0] for p in dark) - min(p[0] for p in dark)) * 0.75))
    feather = px[cx, max(y0, cy - r * 2 - 4)]
    draw = ImageDraw.Draw(im)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=feather)
    draw.arc([cx - r, cy - r // 2, cx + r, cy + r // 2], start=15, end=165,
             fill=(62, 36, 23, 255), width=max(3, r // 3))
    return im


def transform(im: Image.Image, step: dict) -> Image.Image:
    im = im.convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        return im
    if step.get("crop_head"):
        x0, y0, x1, y1 = bbox
        crop = im.crop((x0 + int((x1 - x0) * 0.38), y0, x1,
                        y0 + int((y1 - y0) * 0.62)))
        return crop
    sy = step.get("sy", 1.0)
    if sy != 1.0:
        w, h = im.size
        im = im.resize((w, max(1, int(h * sy))), Image.LANCZOS)
        base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        base.alpha_composite(im, (0, h - im.size[1]))
        im = base
    rot = step.get("rot", 0.0)
    if rot:
        bbox = im.getchannel("A").getbbox()
        cx = (bbox[0] + bbox[2]) // 2
        im = im.rotate(rot, resample=Image.BICUBIC, center=(cx, bbox[3]))
    return im


def place(im: Image.Image, anchor: str, dy: int, size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        return canvas
    crop = im.crop(bbox)
    scale = size / CANVAS
    if anchor == "center":
        factor = (AIRBORNE_MAX * scale) / max(crop.size)
    else:
        factor = (GROUNDED_H * scale) / crop.size[1]
    if crop.size[0] * factor > 470 * scale:
        factor = (470 * scale) / crop.size[0]
    crop = crop.resize((max(1, int(crop.size[0] * factor)),
                        max(1, int(crop.size[1] * factor))), Image.LANCZOS)
    if anchor == "center":
        x = int(size / 2 - crop.size[0] / 2)
        y = int(size / 2 - crop.size[1] / 2) + dy
    else:
        x = int(size / 2 - crop.size[0] / 2)
        y = int(FEET_Y * scale) - crop.size[1] + dy
    canvas.alpha_composite(crop, (x, y))
    return canvas


def nest_image(stage: int) -> Image.Image:
    im = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    out = (62, 36, 23, 255)
    d.rectangle([120, FEET_Y, 392, FEET_Y + 10], fill=(92, 58, 32, 255))
    if stage == 1:
        for x1, y1, x2, y2 in ((196, 470, 286, 446), (216, 472, 300, 456),
                               (246, 472, 316, 448), (206, 466, 268, 470)):
            d.line([x1, y1, x2, y2], fill=(92, 58, 32, 255), width=8)
    if stage == 2:
        d.pieslice([188, 404, 324, 510], 180, 360, fill=(138, 90, 52, 255), outline=out, width=6)
        d.pieslice([206, 422, 306, 510], 180, 360, fill=(110, 69, 37, 255))
    if stage >= 3:
        d.pieslice([176, 358, 336, 520], 180, 360, fill=(138, 90, 52, 255), outline=out, width=6)
        d.ellipse([276, 414, 310, 448], fill=(46, 28, 16, 255))
    if stage == 4:
        d.polygon([(292, 430), (338, 438), (338, 458), (292, 448)],
                  fill=(110, 69, 37, 255), outline=out)
        d.ellipse([214, 386, 238, 398], fill=(217, 140, 78, 255))
    return im


def _load_keyframes() -> dict[str, Image.Image]:
    out = {}
    for path in sorted(POSES_DIR.glob("*.png")):
        out[path.stem] = chroma_key(Image.open(path))
    return out


def _load_orig() -> dict[tuple[str, str], Image.Image]:
    out = {}
    for path in sorted(ORIG_DIR.glob("*.png")):
        skin, _, anim = path.stem.rpartition("-")
        out[(skin, anim)] = Image.open(path).convert("RGBA")
    return out


def _source_image(step: dict, skin_id: str, keyframes, orig) -> Image.Image:
    # keyframes arrives already recolored for palette-only skins.
    src = step["src"]
    if src == "blink-skin":
        base = orig.get((skin_id, "idle")) or keyframes["blink"]
        return paint_blink(base.copy()) if (skin_id, "idle") in orig else base.copy()
    if src.startswith("orig:"):
        anim = src.split(":", 1)[1]
        im = orig.get((skin_id, anim))
        if im is None:
            im = keyframes[{"idle": "idle", "walk": "walk-step",
                            "fly": "fly-down"}[anim]]
        return im.copy()
    return keyframes[src.split(":", 1)[1]].copy()


def _geometry(path: Path, anchor: str) -> dict:
    with Image.open(path) as im:
        assert im.size == (CANVAS, CANVAS), f"{path}: {im.size}"
        bbox = im.convert("RGBA").getchannel("A").getbbox()
    assert bbox is not None, f"{path}: empty frame"
    x0, y0, x1, y1 = bbox
    anchor_px = [256, FEET_Y] if anchor == "feet" else list(FLY_CENTER)
    return {"size": [x1 - x0, y1 - y0], "offset": [x0, y0], "anchorPx": anchor_px}


def _save(im: Image.Image, out: Path, size: int) -> None:
    if size == CANVAS:
        im.quantize(colors=128, method=Image.Quantize.FASTOCTREE).save(
            out, optimize=True)
    else:
        im.save(out, optimize=True)


def derive(out_dir: Path) -> dict:
    frames_dir = out_dir / FRAMES
    hi_dir = out_dir / FRAMES_HI
    frames_dir.mkdir(parents=True, exist_ok=True)
    hi_dir.mkdir(parents=True, exist_ok=True)
    keyframes = _load_keyframes()
    orig = _load_orig()

    manifest_skins: dict[str, dict] = {}
    for skin_id in sorted(poses_mod.SKINS):
        skin = poses_mod.SKINS[skin_id]
        if skin_id in poses_mod.RECOLORS:
            skin_keyframes = {k: recolor(v.copy(), poses_mod.RECOLORS[skin_id])
                              for k, v in keyframes.items()}
        else:
            skin_keyframes = keyframes
        overrides = poses_mod.SKIN_OVERRIDES.get(skin_id, {})
        animations: dict[str, dict] = {}
        for anim, (ms, loop, nxt, anchor, steps) in poses_mod.SEQUENCES.items():
            use_steps = overrides.get(anim, steps)
            frames = []
            for i, step in enumerate(use_steps):
                fname = f"{skin_id}-{anim}-{i + 1:02d}.png"
                src = _source_image(step, skin_id, skin_keyframes, orig)
                placed = place(transform(src, step), anchor,
                               int(step.get("dy", 0)), CANVAS)
                _save(placed, frames_dir / fname, CANVAS)
                if skin_id == "default" and anim in HI_ANIMS:
                    hi = place(transform(
                        _source_image(step, skin_id, skin_keyframes, orig), step),
                        anchor, int(step.get("dy", 0)) * 2, 1024)
                    _save(hi, hi_dir / fname, 1024)
                frame = {"file": f"{FRAMES}/{fname}",
                         **_geometry(frames_dir / fname, anchor)}
                if "ms" in step:
                    frame["ms"] = step["ms"]
                frames.append(frame)
            animations[anim] = {
                "id": anim, "frames": frames, "frameMs": ms,
                "loop": loop, "next": nxt, "anchor": anchor,
            }
        manifest_skins[skin_id] = {
            "label": skin["label"],
            "fallbackChain": [skin_id] if skin_id == "default" else [skin_id, "default"],
            "palette": skin["palette"],
            "animations": animations,
        }

    nests = {}
    for stage, name in enumerate(poses_mod.NEST_STAGES):
        fname = f"nest-{name}.png"
        _save(nest_image(stage), frames_dir / fname, CANVAS)
        nests[name] = f"{FRAMES}/{fname}"

    manifest = {
        "manifestVersion": MANIFEST_VERSION,
        "canvas": {"width": CANVAS, "height": CANVAS},
        "baseline": {"feetY": FEET_Y, "flyCenter": list(FLY_CENTER)},
        "anchors": {"feet": [256, FEET_Y], "center": list(FLY_CENTER)},
        "skins": manifest_skins,
        "assistantStates": dict(poses_mod.ASSISTANT_STATES),
        "nests": nests,
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _drifted(a_path: Path, b_path: Path) -> bool:
    """True when two frames differ beyond encoder/resampler noise."""
    from PIL import ImageChops

    with Image.open(a_path) as fa, Image.open(b_path) as fb:
        a = fa.convert("RGBA")
        b = fb.convert("RGBA")
        if a.size != b.size:
            return True
        diff = ImageChops.difference(a, b)
        total = a.size[0] * a.size[1] * 4
        hist = diff.histogram()
        weighted = sum((i % 256) * count for i, count in enumerate(hist[:256 * 4]))
        mean_abs = weighted / total
        strong = sum(
            count
            for band in range(4)
            for i, count in enumerate(hist[band * 256:(band + 1) * 256])
            if i > 32
        ) / 4
        strong_share = strong / (a.size[0] * a.size[1])
        return mean_abs > 0.5 or strong_share > 0.001


def _structural_check() -> int:
    """Manifest, committed frames and pose sources agree (no render)."""
    problems = []
    manifest = json.loads((COMPANION / "manifest.json").read_text())
    for skin_id, skin in manifest.get("skins", {}).items():
        for anim, entry in skin.get("animations", {}).items():
            if anim not in poses_mod.SEQUENCES:
                problems.append(f"unknown anim in manifest: {anim}")
            for frame in entry.get("frames", []):
                if not (COMPANION / frame["file"]).exists():
                    problems.append(f"missing committed file: {frame['file']}")
    needed = {step["src"].split(":", 1)[1]
              for _m in poses_mod.SEQUENCES.values()
              for step in _m[4] if step["src"].startswith("pose:")}
    for overrides in poses_mod.SKIN_OVERRIDES.values():
        for steps in overrides.values():
            needed |= {s["src"].split(":", 1)[1] for s in steps
                       if s["src"].startswith("pose:")}
    for pose in sorted(needed):
        if not (POSES_DIR / f"{pose}.png").exists():
            problems.append(f"missing pose source: {pose}.png")
    if problems:
        print("derive-companion-assets --check (structural): FAIL", file=sys.stderr)
        for p in problems[:20]:
            print(f"  {p}", file=sys.stderr)
        return 1
    print("derive-companion-assets --check: PASS (structural)")
    return 0


def check() -> int:
    with tempfile.TemporaryDirectory(dir=COMPANION) as tmp:
        fresh = Path(tmp)
        derive(fresh)
        problems = []
        rels = ["manifest.json"]
        for sub in (FRAMES, FRAMES_HI):
            rels += sorted(str(p.relative_to(COMPANION))
                           for p in (COMPANION / sub).glob("*.png"))
        for rel in rels:
            a, b = fresh / rel, COMPANION / rel
            if not b.exists():
                problems.append(f"missing committed file: {rel}")
            elif rel.endswith(".png"):
                if _drifted(a, b):
                    problems.append(f"drift: {rel}")
            elif _sha(a) != _sha(b):
                problems.append(f"drift: {rel}")
        for sub in (FRAMES, FRAMES_HI):
            fresh_set = sorted(str(p.relative_to(fresh))
                               for p in (fresh / sub).glob("*.png"))
            committed_set = sorted(str(p.relative_to(COMPANION))
                                   for p in (COMPANION / sub).glob("*.png"))
            if fresh_set != committed_set:
                problems.append(f"frame set changed in {sub}")
        if problems:
            print("derive-companion-assets --check: FAIL", file=sys.stderr)
            for p in problems[:20]:
                print(f"  {p}", file=sys.stderr)
            return 1
    print("derive-companion-assets --check: PASS")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--structural", action="store_true",
                        help="with --check: verify manifest/sources only")
    args = parser.parse_args()
    if args.check:
        return _structural_check() if args.structural else check()
    derive(COMPANION)
    print("derive-companion-assets: wrote frames + manifest.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
