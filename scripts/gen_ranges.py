#!/usr/bin/env python3
"""Generate config/ranges.json: the one table of user-adjustable numeric ranges.

Source of truth: every `SizeSlider { target: Config.<path> key: "<k>" from: .. to: .. }`
in modules/controlcenter. The table is consumed by the Control Center look-pack import
(clamps to the real range) and checked by tests/test_customisation_ranges.py.
Run `python3 scripts/gen_ranges.py` after changing a slider; `--check` verifies.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "config" / "ranges.json"
BLOCK = re.compile(r"SizeSlider\s*\{(.*?)\n\s*\}", re.S)


def num(body, name, default=None):
    m = re.search(rf"\b{name}:\s*(-?[\d.]+)", body)
    return float(m.group(1)) if m else default


def build():
    table = {}
    for p in sorted((ROOT / "modules" / "controlcenter").rglob("*.qml")):
        for m in BLOCK.finditer(p.read_text()):
            body = m.group(1)
            t = re.search(r"target:\s*Config\.([\w.]+)", body)
            k = re.search(r'key:\s*"(\w+)"', body)
            if not (t and k):
                continue
            entry = {"min": num(body, "from"), "max": num(body, "to"),
                     "step": num(body, "stepSize", 1.0), "default": num(body, "defaultValue")}
            for key in ("min", "max", "step", "default"):
                v = entry[key]
                entry[key] = int(v) if v is not None and v == int(v) else v
            table[f"{t.group(1)}.{k.group(1)}"] = entry
    return dict(sorted(table.items()))


if __name__ == "__main__":
    text = json.dumps({"schema": "hornero/ranges@1", "ranges": build()}, indent=2) + "\n"
    if "--check" in sys.argv:
        sys.exit(0 if OUT.exists() and OUT.read_text() == text else 1)
    OUT.write_text(text)
    print(f"wrote {OUT.relative_to(ROOT)}")
