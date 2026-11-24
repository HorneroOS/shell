#!/usr/bin/env python3
"""Import an existing sprite collection into a Hornero data-only
companion package (PluginKit 6).

Accepts a folder of PNG/WebP frames, Shimeji-style or hand-named.
Frames are mapped to semantic actions by filename keyword
(idle/walk/greet/sleep/...), normalized onto one 512 canvas with a
ground anchor, and written as a complete package directory that
`horneroctl plugin install-local` can validate and install. The
source artwork is copied, never modified, and nothing is uploaded.

Usage:
  companion_import.py <input-dir> <output-dir> --character capi-friend --title "Capi Friend"

This is a converter, not proof of licence: publish only artwork
you have the rights to redistribute (the provenance says so).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image

KEYWORDS = [
    ("sleep", "sleep"), ("rest", "rest"), ("walk", "walk"), ("run", "walk"),
    ("greet", "greet"), ("hello", "greet"), ("talk", "talk"), ("chat", "talk"),
    ("think", "think"), ("work", "work"), ("stretch", "stretch"), ("preen", "preen"),
    ("look", "look"), ("sit", "rest"), ("stand", "idle"), ("idle", "idle"),
]
CANVAS = 512
GROUND_Y = 472


def map_action(name: str) -> str | None:
    low = name.lower()
    for keyword, action in KEYWORDS:
        if keyword in low:
            return action
    return None


def normalize(src: Path, dest: Path) -> None:
    im = Image.open(src).convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit(f"{src}: image has no visible pixels")
    crop = im.crop(bbox)
    scale = min((CANVAS - 40) / crop.width, (CANVAS - 40) / crop.height, 1.0)
    if scale < 1.0:
        crop = crop.resize((round(crop.width * scale), round(crop.height * scale)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(crop, ((CANVAS - crop.width) // 2, GROUND_Y - crop.height))
    canvas.save(dest, optimize=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input_dir", type=Path)
    ap.add_argument("output_dir", type=Path)
    ap.add_argument("--character", required=True, help="character id, e.g. capi-friend (letters/digits)")
    ap.add_argument("--title", required=True)
    ap.add_argument("--package", default=None, help="package id (default: companion-<character>)")
    ap.add_argument("--author", default="Local import")
    args = ap.parse_args()

    if not re.fullmatch(r"[a-z][a-zA-Z0-9]{0,31}", args.character):
        raise SystemExit("--character must match ^[a-z][a-zA-Z0-9]{0,31}$")
    package_id = args.package or f"companion-{args.character}"
    sources = sorted(p for p in args.input_dir.rglob("*") if p.suffix.lower() in {".png", ".webp"} and p.is_file())
    if not sources:
        raise SystemExit(f"{args.input_dir}: no PNG/WebP frames found")

    by_action: dict[str, list[Path]] = {}
    unmapped: list[str] = []
    for src in sources:
        action = map_action(src.stem)
        if action is None:
            unmapped.append(src.name)
            continue
        by_action.setdefault(action, []).append(src)
    if "idle" not in by_action:
        # Shimeji sets often start at a neutral stand frame named 1/shime1.
        numeric = [p for p in sources if re.fullmatch(r"(shime)?\d+", p.stem.lower())]
        if numeric:
            by_action["idle"] = [numeric[0]]
        else:
            raise SystemExit("no frame maps to the mandatory 'idle' action; rename one file to contain 'idle' or 'stand'")

    char = args.character
    root = args.output_dir
    frames_dir = root / "companions" / char / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)
    animations: dict[str, dict] = {}
    files: list[str] = []
    for action, frames in sorted(by_action.items()):
        rel = []
        for index, src in enumerate(frames[:8], 1):
            name = f"{action}-{index:02d}.png"
            normalize(src, frames_dir / name)
            rel.append({"file": f"companions/{char}/frames/{name}", "ms": 700})
            files.append(f"companions/{char}/frames/{name}")
        entry: dict = {"loop": action in {"idle", "walk", "sleep", "rest"}, "anchor": "ground", "frames": rel}
        if not entry["loop"]:
            entry["next"] = "idle"
        animations[action] = entry

    definition = {
        "schemaVersion": 1, "id": char, "version": "1.0.0",
        "names": {"en": args.title},
        "descriptions": {"en": f"Imported local companion ({args.title})."},
        "provenance": {"author": args.author, "license": "Private local import — verify redistribution rights before publishing",
                       "tool": "scripts/companion_import.py"},
        "preview": f"companions/{char}/frames/idle-01.png",
        "canvas": {"width": CANVAS, "height": CANVAS, "anchors": {"ground": [256, GROUND_Y], "center": [256, 256]}},
        "defaultSkin": "default",
        "capabilities": ["grounded"] + (["walk"] if "walk" in animations else []) + (["sleep"] if "sleep" in animations else []) + (["greet"] if "greet" in animations else []),
        "skins": {"default": {"names": {"en": args.title}, "animations": animations}},
        "assistantCompatibility": ["none"],
    }
    (root / "companions" / char / "companion.json").write_text(json.dumps(definition, indent=2, ensure_ascii=False) + "\n")
    (root / "Main.qml").write_text("import QtQuick\n\n// Data-only companion package: rendered natively by the shell.\n\nItem {}\n")
    (root / "README.md").write_text(f"# {args.title}\n\nImported locally with `scripts/companion_import.py`. Data-only companion package (PluginKit 6); the Shell renders it natively.\n")
    (root / "LICENSE").write_text("Private local import. Replace with your licence before publishing.\n")
    files = ["Main.qml", "README.md", "LICENSE", f"companions/{char}/companion.json"] + files
    manifest = {
        "schemaVersion": 3, "pluginKit": 6, "dataOnly": True, "id": package_id,
        "name": args.title, "version": "1.0.0",
        "description": f"Imported data-only companion: {args.title}.",
        "author": args.author, "license": "LicenseRef-LocalImport",
        "entrypoint": "Main.qml", "placement": "background", "files": files,
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
        "contributes": {"companions": [{"id": char, "title": args.title,
                                         "definition": f"companions/{char}/companion.json",
                                         "preview": definition["preview"]}]},
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")

    print(f"imported {sum(len(v) for v in by_action.values())} frames -> {len(animations)} actions into {root}")
    print("actions:", ", ".join(sorted(animations)))
    if unmapped:
        print(f"diagnostics: {len(unmapped)} unmapped file(s) skipped: {', '.join(unmapped[:8])}")
    print("next: horneroctl plugin install-local", root, "--yes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
