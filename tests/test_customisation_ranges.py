"""One range table for user-adjustable numbers, and the `// fixed:` lint."""
import json
import re
import subprocess
import sys
from pathlib import Path

from test_customisation_overview import FACTORY, run_js

ROOT = Path(__file__).resolve().parent.parent
RANGES = json.loads((ROOT / "config" / "ranges.json").read_text())["ranges"]


def _factory_value(path):
    node = FACTORY
    for part in path.split("."):
        node = node[part]
    return node


def test_ranges_table_is_in_sync_with_the_sliders():
    r = subprocess.run([sys.executable, str(ROOT / "scripts" / "gen_ranges.py"), "--check"])
    assert r.returncode == 0, "run: python3 scripts/gen_ranges.py"


def test_every_range_brackets_its_factory_default():
    assert len(RANGES) >= 20
    for path, r in RANGES.items():
        d = _factory_value(path)
        assert r["min"] <= d <= r["max"], path
        assert abs(r["default"] - d) < 1e-6, path
        assert r["step"] > 0 and r["min"] < r["max"], path


def test_pack_import_clamps_to_the_slider_range():
    pack = {"schema": "hornero/look-pack@1", "values": {"launcher.sizes.itemWidth": 99999, "appearance.glow.intensity": 7}}
    r = run_js("return validatePack(D.p, D.f, D.r);", {"p": pack, "f": FACTORY, "r": RANGES})
    got = {a["path"]: a["value"] for a in r["accepted"]}
    assert got["launcher.sizes.itemWidth"] == RANGES["launcher.sizes.itemWidth"]["max"]
    assert got["appearance.glow.intensity"] == 1.5


# --- `// fixed:` lint -------------------------------------------------------
# Debatable visual values must be tokens (Appearance.rounding/font) or carry a
# `// fixed: <reason>` comment. Scoped: only `radius:` and `font.pointSize:`
# numeric literals, and only growth over the recorded baseline fails, so
# existing files and other work in flight are not affected. To fix a failure,
# use Appearance.rounding.* / Appearance.font.size.*, or justify the literal
# with `// fixed: why`. Lower the baseline (tests/fixed_baseline.json) as
# literals are converted.
LITERAL = re.compile(r"^\s*(?:radius|font\.pointSize):\s*\d[\d.]*\s*(?://(?!\s*fixed:).*)?$")
BASELINE = json.loads((Path(__file__).parent / "fixed_baseline.json").read_text())


def _counts():
    out = {}
    for d in ("components", "modules"):
        for p in sorted((ROOT / d).rglob("*.qml")):
            n = sum(1 for line in p.read_text().splitlines() if LITERAL.match(line))
            if n:
                out[str(p.relative_to(ROOT))] = n
    return out


def test_no_new_unjustified_visual_literals():
    grew = {f: (n, BASELINE.get(f, 0)) for f, n in _counts().items() if n > BASELINE.get(f, 0)}
    assert not grew, (
        "new hard-coded radius/font size literals (file: now, baseline). Use Appearance.rounding.* or "
        f"Appearance.font.size.*, or add `// fixed: reason`: {grew}")
