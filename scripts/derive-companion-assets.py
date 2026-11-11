#!/usr/bin/env python3
"""Derive Companion frames + manifest from parameterized SVG masters.

Pipeline (deterministic; Pillow + rsvg-convert):
  scripts/companion_art.py (pose parameters, palettes, character bible)
  -> assets/companion/sources/svg/*.svg (skin-neutral masters, tokens)
  -> per-skin token substitution -> rsvg-convert 512x512 (+1024 hi set)
  -> assets/companion/frames/*.png + manifest.json (v2).

Every skin ships every animation (poses are authored once; skins are
palette + garment/accessory substitutions), so no skin flies bare.
The pre-reboot artist plates stay under sources/ as provenance.

Usage:
  scripts/derive-companion-assets.py            # write sources, frames, manifest
  scripts/derive-companion-assets.py --check    # verify committed output
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import companion_art as art  # noqa: E402

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    print("derive-companion-assets: SKIP (Pillow not installed)", file=sys.stderr)
    sys.exit(3)

ROOT = Path(__file__).resolve().parent.parent
COMPANION = ROOT / "assets" / "companion"
SVG_SOURCES = COMPANION / "sources" / "svg"
FRAMES = "frames"
FRAMES_HI = "frames-hi"

CANVAS = 512
FEET_Y = 472
FLY_CENTER = (256, 256)
MANIFEST_VERSION = 2
EYE_COLOR = "#1D130C"
HI_ANIMS = ("idle", "greet", "fly", "perch")


def _substitute(svg: str, skin_id: str) -> str:
    skin = art.SKINS[skin_id]
    out = svg.replace("@GARMENT@", art._garment(skin["garment"]))
    out = out.replace("@ACCESSORIES@", art._accessories(skin["accessories"]))
    for key, value in skin["palette"].items():
        out = out.replace(f"@{key.upper()}@", value)
    return out.replace("@EYEC@", EYE_COLOR)


def _render(svg_text: str, out: Path, size: int) -> None:
    rsvg = shutil.which("rsvg-convert")
    if rsvg is None:  # pragma: no cover - authoring hosts carry librsvg
        raise RuntimeError("rsvg-convert not found (install librsvg)")
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as tmp:
        tmp.write(svg_text)
        tmp_path = tmp.name
    try:
        subprocess.run([rsvg, "-w", str(size), "-h", str(size), tmp_path,
                        "-o", str(out)], check=True, capture_output=True)
    finally:
        Path(tmp_path).unlink(missing_ok=True)
    if size == CANVAS:
        # Flat art quantizes losslessly at 128 colors (~75% smaller);
        # hi-res exports stay full RGBA for the website.
        with Image.open(out) as im:
            im.convert("RGBA").quantize(
                colors=128, method=Image.Quantize.FASTOCTREE).save(
                out, optimize=True)


def _geometry(path: Path, anchor: str) -> dict:
    with Image.open(path) as im:
        assert im.size == (CANVAS, CANVAS), f"{path}: {im.size}"
        bbox = im.convert("RGBA").getchannel("A").getbbox()
    assert bbox is not None, f"{path}: empty frame"
    x0, y0, x1, y1 = bbox
    anchor_px = [256, FEET_Y] if anchor == "feet" else list(FLY_CENTER)
    return {"size": [x1 - x0, y1 - y0], "offset": [x0, y0], "anchorPx": anchor_px}


def derive(out_dir: Path, write_sources: bool = False) -> dict:
    frames_dir = out_dir / FRAMES
    hi_dir = out_dir / FRAMES_HI
    frames_dir.mkdir(parents=True, exist_ok=True)
    hi_dir.mkdir(parents=True, exist_ok=True)
    if write_sources:
        SVG_SOURCES.mkdir(parents=True, exist_ok=True)

    # Pose masters (skin-neutral), keyed (anim, index).
    masters: dict[tuple[str, int], str] = {}
    for anim, (_ms, _loop, _next, _anchor, poses) in art.ANIMATIONS.items():
        for i, pose in enumerate(poses):
            masters[(anim, i)] = art.pose_svg(pose)
    nest_masters = {stage: art.nest_svg(stage) for stage in range(5)}
    if write_sources:
        for (anim, i), svg in masters.items():
            (SVG_SOURCES / f"{anim}-{i + 1:02d}.svg").write_text(svg + "\n")
        for stage, name in enumerate(art.NEST_STAGES):
            (SVG_SOURCES / f"nest-{name}.svg").write_text(nest_masters[stage] + "\n")
        (SVG_SOURCES / "skins.json").write_text(
            json.dumps(art.SKINS, indent=2) + "\n")

    manifest_skins: dict[str, dict] = {}
    for skin_id in sorted(art.SKINS):
        skin = art.SKINS[skin_id]
        animations: dict[str, dict] = {}
        for anim, (ms, loop, nxt, anchor, poses) in art.ANIMATIONS.items():
            frames = []
            for i, _pose in enumerate(poses):
                fname = f"{skin_id}-{anim}-{i + 1:02d}.png"
                _render(_substitute(masters[(anim, i)], skin_id),
                        frames_dir / fname, CANVAS)
                if skin_id == "default" and anim in HI_ANIMS:
                    _render(_substitute(masters[(anim, i)], skin_id),
                            hi_dir / fname, 1024)
                frames.append({"file": f"{FRAMES}/{fname}",
                               **_geometry(frames_dir / fname, anchor)})
            animations[anim] = {
                "id": anim, "frames": frames, "frameMs": ms,
                "loop": loop, "next": nxt, "anchor": anchor,
            }
        manifest_skins[skin_id] = {
            "label": skin["label"],
            "fallbackChain": [skin_id] if skin_id == "default" else [skin_id, "default"],
            "palette": skin["palette"],
            "garment": skin["garment"],
            "accessories": skin["accessories"],
            "animations": animations,
        }

    nests = {}
    for stage, name in enumerate(art.NEST_STAGES):
        fname = f"nest-{name}.png"
        _render(nest_masters[stage], frames_dir / fname, CANVAS)
        nests[name] = f"{FRAMES}/{fname}"

    manifest = {
        "manifestVersion": MANIFEST_VERSION,
        "canvas": {"width": CANVAS, "height": CANVAS},
        "baseline": {"feetY": FEET_Y, "flyCenter": list(FLY_CENTER)},
        "anchors": {"feet": [256, FEET_Y], "center": list(FLY_CENTER)},
        "skins": manifest_skins,
        "assistantStates": dict(art.ASSISTANT_STATES),
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


def check() -> int:
    with tempfile.TemporaryDirectory() as tmp:
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
        # Committed SVG masters must match the generator output.
        for (anim, i), svg in sorted(
                ((a, i), art.pose_svg(p))
                for a, (_m, _l, _n, _an, poses) in art.ANIMATIONS.items()
                for i, p in enumerate(poses)):
            committed = SVG_SOURCES / f"{anim}-{i + 1:02d}.svg"
            if not committed.exists() or committed.read_text() != svg + "\n":
                problems.append(f"svg drift: {committed.name}")
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
    args = parser.parse_args()
    if args.check:
        return check()
    derive(COMPANION, write_sources=True)
    print("derive-companion-assets: wrote SVG sources, frames + manifest.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
