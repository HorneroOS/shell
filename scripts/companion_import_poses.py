#!/usr/bin/env python3
"""Import a poses folder into a Hornero data-only
companion package (PluginKit 6).

Accepts the poses layout: a directory containing
``poses.json`` plus the single-frame PNG stills it names (the source folder). Each pose is mapped
onto Hornero's closed semantic action vocabulary:

    idle -> idle (loop)       think -> think       cast -> work
    reading -> look           happy -> greet       celebrate -> celebrate
    sad -> worry + error      sleep -> sleep (loop)

The ``eyes``/``glow`` coordinates in ``poses.json`` have no Hornero
equivalent; they are reported as diagnostics and dropped. Frames are
normalized onto one 512 canvas with a ground anchor, exactly like
``scripts/companion_import.py``.

This converter ships no artwork: it only reads a poses folder the
user already has. Publishing the result redistributes someone
else's character, so ``--author``/``--license`` (and ideally
``--source``/``--attribution``) must state the real rights holder;
the output package carries that provenance verbatim.

Usage:
  companion_import_poses.py <poses-dir> <output-dir> \
      --character mycompanion --title "My Companion" \
      --author "<rights holder>" --license "<license>" \
      [--source https://...] [--attribution "..."]

This is a converter, not proof of licence: publish only artwork
you have the rights to redistribute.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image

# Pose id -> Hornero semantic actions. One pose may feed two
# actions (sad covers both worry and error); two poses may merge
# into one action only when they are distinct actions already.
POSE_ACTIONS: dict[str, list[str]] = {
    "idle": ["idle"],
    "think": ["think"],
    "cast": ["work"],
    "reading": ["look"],
    "happy": ["greet"],
    "celebrate": ["celebrate"],
    "sad": ["worry", "error"],
    "sleep": ["sleep"],
}
LOOP_ACTIONS = {"idle", "sleep", "think", "work", "look"}
CANVAS = 512
GROUND_Y = 472


def normalize(src: Path, dest: Path) -> None:
    im = Image.open(src).convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit(f"{src}: image has no visible pixels")
    crop = im.crop(bbox)
    scale = min((CANVAS - 40) / crop.width, (CANVAS - 40) / crop.height, 1.0)
    if scale < 1.0:
        crop = crop.resize(
            (round(crop.width * scale), round(crop.height * scale)),
            Image.Resampling.LANCZOS,
        )
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(crop, ((CANVAS - crop.width) // 2, GROUND_Y - crop.height))
    canvas.save(dest, optimize=True)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("poses_dir", type=Path)
    ap.add_argument("output_dir", type=Path)
    ap.add_argument("--character", required=True, help="character id, e.g. mycompanion (letters/digits)")
    ap.add_argument("--title", required=True)
    ap.add_argument("--package", default=None, help="package id (default: companion-<character>)")
    ap.add_argument("--author", required=True, help="real rights holder / package author")
    ap.add_argument("--license", required=True, help="license the rights holder publishes under")
    ap.add_argument("--source", default=None, help="https:// URL of the source project")
    ap.add_argument("--attribution", default=None, help="attribution for the underlying character/art")
    args = ap.parse_args()

    if not re.fullmatch(r"[a-z][a-zA-Z0-9]{0,31}", args.character):
        raise SystemExit("--character must match ^[a-z][a-zA-Z0-9]{0,31}$")
    if args.source and not args.source.startswith("https://"):
        raise SystemExit("--source must be an https:// URL")
    package_id = args.package or f"companion-{args.character}"

    poses_file = args.poses_dir / "poses.json"
    if not poses_file.is_file():
        raise SystemExit(f"{poses_file}: not found (expected a poses folder)")
    try:
        poses_doc = json.loads(poses_file.read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{poses_file}: invalid JSON: {exc}") from exc
    poses = poses_doc.get("poses")
    if not isinstance(poses, dict) or not poses:
        raise SystemExit(f"{poses_file}: no 'poses' object found")

    by_action: dict[str, Path] = {}
    unmapped: list[str] = []
    dropped_meta: list[str] = []
    for pose_id, meta in sorted(poses.items()):
        if not isinstance(meta, dict) or not isinstance(meta.get("file"), str):
            unmapped.append(f"{pose_id} (no file)")
            continue
        src = args.poses_dir / meta["file"]
        if not src.is_file():
            unmapped.append(f"{pose_id} (missing {meta['file']})")
            continue
        actions = POSE_ACTIONS.get(pose_id)
        if actions is None:
            unmapped.append(pose_id)
            continue
        if meta.get("eyes") or meta.get("glow"):
            dropped_meta.append(pose_id)
        for action in actions:
            by_action.setdefault(action, src)
    if "idle" not in by_action:
        raise SystemExit("no pose maps to the mandatory 'idle' action; an 'idle' pose is required")

    char = args.character
    root = args.output_dir
    frames_dir = root / "companions" / char / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)
    animations: dict[str, dict] = {}
    files: list[str] = []
    for action, src in sorted(by_action.items()):
        name = f"{action}-01.png"
        normalize(src, frames_dir / name)
        rel = f"companions/{char}/frames/{name}"
        files.append(rel)
        entry: dict = {
            "loop": action in LOOP_ACTIONS,
            "anchor": "ground",
            "frames": [{"file": rel, "ms": 900}],
        }
        if not entry["loop"]:
            entry["next"] = "idle"
        animations[action] = entry

    capabilities = ["grounded"]
    for action, cap in (("think", "think"), ("work", "work"), ("sleep", "sleep"),
                        ("greet", "greet"), ("celebrate", "celebrate")):
        if action in animations and cap not in capabilities:
            capabilities.append(cap)
    if "worry" in animations or "error" in animations:
        capabilities.append("concern")

    provenance: dict[str, str] = {
        "author": args.author,
        "license": args.license,
        "tool": "scripts/companion_import_poses.py",
    }
    if args.source:
        provenance["source"] = args.source
    if args.attribution:
        provenance["attribution"] = args.attribution

    definition = {
        "schemaVersion": 1, "id": char, "version": "1.0.0",
        "names": {"en": args.title},
        "descriptions": {"en": f"Imported poses-folder companion ({args.title})."},
        "provenance": provenance,
        "preview": f"companions/{char}/frames/idle-01.png",
        "canvas": {"width": CANVAS, "height": CANVAS,
                   "anchors": {"ground": [256, GROUND_Y], "center": [256, 256]}},
        "defaultSkin": "default",
        "capabilities": capabilities,
        "skins": {"default": {"names": {"en": args.title}, "animations": animations}},
        "assistantCompatibility": ["none"],
    }
    (root / "companions" / char / "companion.json").write_text(
        json.dumps(definition, indent=2, ensure_ascii=False) + "\n")
    (root / "Main.qml").write_text(
        "import QtQuick\n\n// Data-only companion package: rendered natively by the shell.\n\nItem {}\n")
    (root / "README.md").write_text(
        f"# {args.title}\n\nImported from a poses folder with "
        f"`scripts/companion_import_poses.py`. Data-only companion package "
        f"(PluginKit 6); the Shell renders it natively. See the provenance "
        f"in `companions/{char}/companion.json` for authorship and licence.\n")
    (root / "LICENSE").write_text(
        f"{args.license}\n\nSee provenance in companions/{char}/companion.json "
        f"for the rights holder and attribution.\n")
    files = ["Main.qml", "README.md", "LICENSE", f"companions/{char}/companion.json"] + files
    manifest = {
        "schemaVersion": 3, "pluginKit": 6, "dataOnly": True, "id": package_id,
        "name": args.title, "version": "1.0.0",
        "description": f"Imported data-only companion: {args.title}.",
        "author": args.author, "license": args.license,
        "entrypoint": "Main.qml", "placement": "background", "files": files,
        "capabilities": {"processCommands": [], "networkHosts": [], "settings": {}},
        "contributes": {"companions": [{"id": char, "title": args.title,
                                         "definition": f"companions/{char}/companion.json",
                                         "preview": definition["preview"]}]},
    }
    (root / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")

    print(f"imported {len(by_action)} actions from {len(poses)} poses into {root}")
    print("actions:", ", ".join(sorted(animations)))
    if dropped_meta:
        print(f"diagnostics: eyes/glow metadata dropped for: {', '.join(dropped_meta)} "
              f"(no Hornero equivalent)")
    if unmapped:
        print(f"diagnostics: {len(unmapped)} unmapped pose(s) skipped: {', '.join(unmapped[:8])}")
    print("next: horneroctl plugin install-local", root, "--yes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
