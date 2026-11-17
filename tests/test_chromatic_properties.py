"""Every generated palette passes its gates (RFC 0002 §15 property matrix).

corpus × 8 variants × 2 modes × 3 contrast levels, plus 64 manual seeds,
checked by the engine's own gate report and — when HORNERO_CONFIG_DIR is
set — by config's `signal_theme.validate_scheme` at the resolved level.
Also: determinism across runs, and the corpus expectations in cases.json.
"""
import math
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent / "chromatic"))
import harness  # noqa: E402

MODES = ["dark", "light"]


def _hue(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]
    l_ = (0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2]) ** (1 / 3)
    m_ = (0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969566 * lin[2]) ** (1 / 3)
    s_ = (0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2]) ** (1 / 3)
    a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
    bb = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
    return math.degrees(math.atan2(bb, a)) % 360


def _hue_gap(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def _check(doc, label):
    assert doc is not None and "error" not in doc, f"{label}: {doc and doc.get('error')}"
    assert doc["gates"]["passed"], f"{label}: engine gate report failed"
    validator = harness.config_validator()
    if validator is not None:
        level = doc["scheme"]["chromatic"]["resolved"]["contrast"]
        errors = validator.validate_scheme(doc["scheme"], level)
        assert not errors, f"{label}: config validate_scheme: {errors[:3]}"


def _matrix_jobs():
    jobs = []
    for case in harness.CASES["cases"]:
        if not case.get("golden"):
            continue
        path = harness.corpus() / case["file"]
        for variant in harness.VARIANTS:
            for mode in MODES:
                for level in harness.LEVELS:
                    jobs.append((f"{case['name']}/{variant}/{mode}/{level}",
                                 ["generate", "--source", str(path), "--variant", variant, "--mode", mode,
                                  "--contrast", level]))
    for i in range(64):
        hue = i * 5.625
        chroma = 0.04 + (i % 8) * 0.03
        L, a, b = 0.68, chroma * math.cos(math.radians(hue)), chroma * math.sin(math.radians(hue))
        l_, m_, s_ = (L + 0.3963377774 * a + 0.2158037573 * b, L - 0.1055613458 * a - 0.0638541728 * b,
                      L - 0.0894841775 * a - 1.2914855480 * b)
        lr = [4.0767416621 * l_**3 - 3.3077115913 * m_**3 + 0.2309699292 * s_**3,
              -1.2684380046 * l_**3 + 2.6097574011 * m_**3 - 0.3413193965 * s_**3,
              -0.0041960863 * l_**3 - 0.7034186147 * m_**3 + 1.7076147010 * s_**3]
        enc = [min(max(12.92 * c if c <= 0.0031308 else 1.055 * max(c, 0) ** (1 / 2.4) - 0.055, 0), 1) for c in lr]
        seed = "#" + "".join(f"{round(c * 255):02X}" for c in enc)
        for variant in harness.VARIANTS:
            for mode in MODES:
                for level in harness.LEVELS:
                    jobs.append((f"seed {seed}/{variant}/{mode}/{level}",
                                 ["generate", "--seed", seed, "--variant", variant, "--mode", mode,
                                  "--contrast", level]))
    return jobs


def test_every_palette_passes_its_gates():
    jobs = _matrix_jobs()
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda job: (job[0], harness.run(*job[1])), jobs))
    failures = []
    for label, (rc, doc, _) in results:
        try:
            assert rc == 0, f"{label}: exit {rc}"
            _check(doc, label)
        except AssertionError as exc:
            failures.append(str(exc))
    assert not failures, f"{len(failures)}/{len(jobs)} palettes fail:\n" + "\n".join(failures[:20])


def test_byte_identical_across_runs():
    for name in ("noise", "gif-anim", "hue-sweep"):
        args = ("generate", "--source", str(harness.case_path(name)), "--variant", "expressive")
        outs = {harness.run(*args)[2] for _ in range(3)}
        assert len(outs) == 1, name


def _gen(name, *extra):
    rc, doc, _ = harness.run("generate", "--source", str(harness.case_path(name)), *extra)
    assert rc == 0, name
    return doc


@pytest.mark.parametrize("case", [c for c in harness.CASES["cases"] if c["expect"]], ids=lambda c: c["name"])
def test_corpus_expectations(case):
    exp = case["expect"]
    path = harness.corpus() / case["file"]
    if case.get("optional") and not path.exists():
        pytest.skip(f"{case['name']}: not produced here (no encoder/ffmpeg)")
    if "exit" in exp:
        rc, doc, _ = harness.run("generate", "--source", str(path))
        assert rc == exp["exit"] and doc["error"]["code"] == "source-unreadable"
        return
    rc, doc, _ = harness.run("generate", "--source", str(path))
    if exp.get("decodesOrUnreadable"):
        assert rc in (0, 3)
        return
    assert rc == 0
    inf, ana, pal = doc["inference"], doc["analysis"], doc["scheme"]["palette"]
    if "mode" in exp:
        assert inf["mode"] == exp["mode"]
    if "variant" in exp:
        assert inf["variant"] == exp["variant"]
    if "achromatic" in exp:
        assert ana["achromatic"] is exp["achromatic"]
    if exp.get("hysteresis"):
        lit = harness.run("generate", "--source", str(path), "--current-mode", "light")[1]
        assert lit["inference"]["mode"] == "light" and inf["mode"] == "dark"
    if "detailAbove" in exp:
        assert ana["detail"] > exp["detailAbove"]
        assert any("boosted" in r for r in inf["reasons"])
    if "twoSeedsApart" in exp:
        hues = [s["oklch"][2] for s in ana["seeds"]]
        assert any(_hue_gap(hues[0], h) >= exp["twoSeedsApart"] for h in hues[1:])
    if "primaryHue" in exp:
        lo, hi = exp["primaryHue"]
        assert lo <= ana["seeds"][0]["oklch"][2] <= hi
    if "suggestion" in exp:
        assert inf["suggestion"] == exp["suggestion"] and inf["variant"] != "neon"
    if "temperature" in exp:
        assert inf["temperature"] == exp["temperature"]
    if exp.get("primaryNotOlive"):
        h = ana["seeds"][0]["oklch"][2]
        assert not 90 <= h <= 115
    if "signalAlertHueMin" in exp:
        assert _hue_gap(_hue(pal["signal"]), _hue(pal["alert"])) >= exp["signalAlertHueMin"]
    if "cuePhosphorHueMin" in exp:
        assert _hue_gap(_hue(pal["cue"]), _hue(pal["phosphor"])) >= exp["cuePhosphorHueMin"]
    if "sameSeedsAs" in exp:
        other = harness.run("generate", "--source", str(harness.corpus() / exp["sameSeedsAs"]))[1]
        assert other["scheme"]["palette"] == pal
    if "closeTo" in exp:
        other = harness.run("generate", "--source", str(harness.corpus() / exp["closeTo"]))[1]
        a = [s["oklch"] for s in ana["seeds"]][0]
        b = [s["oklch"] for s in other["analysis"]["seeds"]][0]
        assert abs(a[0] - b[0]) < exp["maxDeltaEOK"] and abs(a[1] - b[1]) < exp["maxDeltaEOK"]
    if "differsFrom" in exp:
        other = harness.run("generate", "--source", str(harness.corpus() / exp["differsFrom"]))[1]
        assert other["analysis"]["seeds"][0]["hex"] != ana["seeds"][0]["hex"]
    if "kind" in exp:
        assert ana["kind"] == exp["kind"]
    if "distinctSeedHues" in exp:
        hues = [s["oklch"][2] for s in ana["seeds"] if s["oklch"][1] > 0.04]
        distinct = [h for i, h in enumerate(hues) if all(_hue_gap(h, g) > 30 for g in hues[:i])]
        assert len(distinct) >= exp["distinctSeedHues"]
