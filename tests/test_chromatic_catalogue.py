"""Chromatic over the credited catalogue wallpapers in HorneroOS/config.

HORNERO_CONFIG_DIR points at a config checkout (CI: the commit pinned in
libs/chromatic/data/contrast-gates.sha). Goldens (`auto` and `balanced`,
mode auto) live in tests/chromatic/golden-catalogue/ and are compared with
the same ΔEOK 0.005 cross-toolchain tolerance as the corpus goldens; every
variant × mode must pass config's validate_scheme.
"""
import json
import math
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent / "chromatic"))
import harness  # noqa: E402

GOLDEN = harness.ROOT / "tests" / "chromatic" / "golden-catalogue"
SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


def _wallpapers():
    base = os.environ.get("HORNERO_CONFIG_DIR")
    if not base or not (Path(base) / "assets" / "wallpapers").is_dir():
        pytest.skip("HORNERO_CONFIG_DIR with assets/wallpapers not set")
    walls = sorted(p for p in (Path(base) / "assets" / "wallpapers").rglob("*") if p.suffix.lower() in SUFFIXES)
    assert walls, "config ships no wallpapers"
    return walls


def _oklab(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]
    l_ = (0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2]) ** (1 / 3)
    m_ = (0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969566 * lin[2]) ** (1 / 3)
    s_ = (0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2]) ** (1 / 3)
    return (0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_)


def _summary(doc):
    s = doc["scheme"]
    return {"mode": s["mode"], "variant": doc["inference"]["variant"], "palette": s["palette"],
            "terminal": s["terminal"], "minSurfaceAlpha": s["minSurfaceAlpha"], "clearInk": s["clearInk"]}


def test_catalogue_goldens():
    walls = _wallpapers()
    update = os.environ.get("CHROMATIC_UPDATE_GOLDEN") == "1"
    jobs = [(w, v) for w in walls for v in ("auto", "balanced")]
    with ThreadPoolExecutor(max_workers=4) as pool:
        docs = list(pool.map(lambda j: harness.run("generate", "--source", str(j[0]), "--variant", j[1]), jobs))
    problems = []
    for (wall, variant), (rc, doc, _) in zip(jobs, docs):
        assert rc == 0, (wall.name, doc)
        path = GOLDEN / f"{wall.stem}__{variant}.json"
        got = _summary(doc)
        if update:
            GOLDEN.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(got, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")
            continue
        if not path.exists():
            problems.append(f"missing {path.name}")
            continue
        want = json.loads(path.read_text(encoding="utf-8"))
        if want == got:
            continue
        if (want["mode"], want["variant"]) != (got["mode"], got["variant"]):
            problems.append(f"{path.name}: inference changed")
            continue
        pairs = [(want["palette"][k], got["palette"].get(k, "#000000")) for k in want["palette"]]
        pairs += list(zip(want["terminal"], got["terminal"]))
        worst = max(math.dist(_oklab(a), _oklab(b)) for a, b in pairs)
        if worst > 0.005:
            problems.append(f"{path.name}: dEOK {worst:.4f} > 0.005")
    assert not problems, "\n".join(problems)


def test_catalogue_every_variant_passes_config():
    walls = _wallpapers()
    validator = harness.config_validator()
    jobs = [(w, v, m) for w in walls for v in harness.VARIANTS for m in ("dark", "light")]
    with ThreadPoolExecutor(max_workers=4) as pool:
        docs = list(pool.map(lambda j: harness.run("generate", "--source", str(j[0]), "--variant", j[1],
                                                   "--mode", j[2]), jobs))
    bad = []
    for (wall, variant, mode), (rc, doc, _) in zip(jobs, docs):
        if rc != 0 or not doc["gates"]["passed"]:
            bad.append(f"{wall.name} {variant} {mode}: exit {rc}")
        elif validator is not None:
            errors = validator.validate_scheme(doc["scheme"], doc["scheme"]["chromatic"]["resolved"]["contrast"])
            if errors:
                bad.append(f"{wall.name} {variant} {mode}: {errors[:2]}")
    assert not bad, "\n".join(bad)
