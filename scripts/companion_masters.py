#!/usr/bin/env python3
"""Raster master ingestion for the Companion (first-class, art-agnostic).

Character art direction is separate from animation engineering: a master is
any high-quality RGBA PNG/WebP (painted, generated externally, or exported
from vector) registered in assets/companion/masters.json. This module
validates and normalises masters; the derive pipeline consumes the result.

Registry entry:
  {"id": "idle", "file": "sources/masters/idle.png", "sha256": "...",
   "pose": "idle", "anchor": "feet", "pivot": [x, y],   # pivot in master px
   "origin": "external|procedural|vector",
   "provenance": {"tool": "...", "prompt": "docs/art/briefs/idle.md",
                  "date": "YYYY-MM-DD", "licence": "...", "author": "..."}}

Rules (checked by --check and tests; no Pillow needed for the registry part):
  * sha256 pinned; a changed file fails until the pin is updated on purpose
  * external art must carry tool, prompt, date and licence
  * size budget: <= 4 MiB per master, min 1024 px on the long side, <= 4096
  * real alpha: corners transparent, content margin >= 2% of the canvas,
    pivot inside the opaque bounding box column span
  * no baked checkerboard/labels (opaque fraction of the border must be 0)

  companion_masters.py --check
  companion_masters.py --matte in.png out.png   # defringe + despeckle helper
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COMPANION = ROOT / "assets" / "companion"
REGISTRY = COMPANION / "masters.json"
MAX_BYTES = 4 * 1024 * 1024
MIN_SIDE, MAX_SIDE = 1024, 4096
ORIGINS = {"external", "procedural", "vector"}
POSES = {"idle", "think", "sleep", "listen", "work", "approve", "deny",
         "worry", "error", "celebrate", "walk", "fly", "talk", "greet",
         "blink", "look", "preen", "stretch", "hop", "takeoff", "land",
         "perch", "peek", "drag", "hover"}


def load_registry(path: Path = REGISTRY) -> list[dict]:
    data = json.loads(path.read_text())
    if data.get("schema") != 1 or not isinstance(data.get("masters"), list):
        raise ValueError("masters.json: schema must be 1 with a masters list")
    return data["masters"]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_entry(e: dict, base: Path = COMPANION, check_pixels: bool = True) -> list[str]:
    errs: list[str] = []
    for k in ("id", "file", "sha256", "pose", "anchor", "pivot", "origin"):
        if k not in e:
            errs.append(f"{e.get('id', '?')}: missing {k}")
    if errs:
        return errs
    mid = e["id"]
    if e["pose"] not in POSES:
        errs.append(f"{mid}: unknown pose {e['pose']}")
    if e["anchor"] not in ("feet", "center"):
        errs.append(f"{mid}: anchor must be feet or center")
    if e["origin"] not in ORIGINS:
        errs.append(f"{mid}: origin must be one of {sorted(ORIGINS)}")
    if e["origin"] == "external":
        prov = e.get("provenance") or {}
        for k in ("tool", "prompt", "date", "licence"):
            if not prov.get(k):
                errs.append(f"{mid}: external art needs provenance.{k}")
    if not (isinstance(e["pivot"], list) and len(e["pivot"]) == 2):
        errs.append(f"{mid}: pivot must be [x, y]")
    path = base / e["file"]
    if not path.is_file():
        return errs + [f"{mid}: file missing {e['file']}"]
    if path.stat().st_size > MAX_BYTES:
        errs.append(f"{mid}: {path.stat().st_size} bytes exceeds budget {MAX_BYTES}")
    if sha256(path) != e["sha256"]:
        errs.append(f"{mid}: sha256 pin mismatch")
    if check_pixels:
        errs += _pixel_checks(mid, path, e)
    return errs


def _pixel_checks(mid: str, path: Path, e: dict) -> list[str]:
    try:
        from PIL import Image
    except ImportError:  # pragma: no cover
        return []
    errs: list[str] = []
    with Image.open(path) as im:
        im = im.convert("RGBA")
        w, h = im.size
        if not (MIN_SIDE <= max(w, h) <= MAX_SIDE):
            errs.append(f"{mid}: long side {max(w, h)} outside {MIN_SIDE}-{MAX_SIDE}")
        a = im.getchannel("A")
        bbox = a.getbbox()
        if bbox is None:
            return errs + [f"{mid}: fully transparent"]
        if a.getextrema()[0] != 0:
            errs.append(f"{mid}: no transparent pixels (baked background?)")
        px = a.load()
        border = [px[x, 0] for x in range(w)] + [px[x, h - 1] for x in range(w)] \
            + [px[0, y] for y in range(h)] + [px[w - 1, y] for y in range(h)]
        if any(v > 8 for v in border):
            errs.append(f"{mid}: opaque pixels on the canvas border (cropped or baked background)")
        m = 0.02
        x0, y0, x1, y1 = bbox
        if x0 < w * m or y0 < h * m or x1 > w * (1 - m) or y1 > h * (1 - m):
            errs.append(f"{mid}: content margin under 2% of the canvas")
        px_, py_ = e["pivot"]
        if not (x0 <= px_ <= x1 and 0 <= py_ <= h):
            errs.append(f"{mid}: pivot {e['pivot']} outside content columns {x0}-{x1}")
    return errs


def matte(src: Path, dst: Path) -> None:
    """Defringe a master: pull edge colour inward (kills white/green halos),
    drop isolated specks, keep full resolution and the original alpha ramp."""
    from PIL import Image, ImageFilter
    im = Image.open(src).convert("RGBA")
    a = im.getchannel("A")
    core = a.point(lambda v: 255 if v > 200 else 0).filter(ImageFilter.MinFilter(3))
    rgb = im.convert("RGB")
    bleed = rgb.copy()
    for _ in range(3):  # inward colour bleed from the opaque core
        bleed = Image.composite(rgb, bleed.filter(ImageFilter.MaxFilter(3)), core)
    out = Image.composite(rgb, bleed, a.point(lambda v: 255 if v > 245 else 0))
    out.putalpha(a)
    out.save(dst, optimize=True)


def check() -> int:
    errs: list[str] = []
    ids = set()
    for e in load_registry():
        if e.get("id") in ids:
            errs.append(f"duplicate id {e.get('id')}")
        ids.add(e.get("id"))
        errs += validate_entry(e)
    for line in errs:
        print("companion-masters:", line, file=sys.stderr)
    print("companion-masters: FAIL" if errs else f"companion-masters: ok ({len(ids)} masters)")
    return 1 if errs else 0


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--matte":
        matte(Path(sys.argv[2]), Path(sys.argv[3]))
    else:
        sys.exit(check())
