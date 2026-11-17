"""Golden output of the helper over the synthetic corpus (RFC 0002 §15).

tests/chromatic/golden/<case>__<variant>__<mode>.json hold the helper's
compact `generate` document (absolute corpus paths normalised). Output is
byte-exact for a given toolchain; across toolchains every colour may move
by at most ΔEOK 0.005 (RFC §15). CHROMATIC_GOLDEN_STRICT=1 demands bytes.
Regenerate only with CHROMATIC_UPDATE_GOLDEN=1 and an `algorithm` bump.
"""
import json
import math
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "chromatic"))
import harness  # noqa: E402

VARIANTS = ["auto", *harness.VARIANTS]
MODES = ["auto", "dark", "light"]


def _oklab(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]
    l_ = (0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2]) ** (1 / 3)
    m_ = (0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969566 * lin[2]) ** (1 / 3)
    s_ = (0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2]) ** (1 / 3)
    return (0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_)


def _normalise(doc, case):
    doc["request"]["path"] = f"corpus:{case['file']}"
    return json.dumps(doc, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n"


def _colours(scheme):
    out = dict(scheme["palette"])
    out.update({f"terminal{i}": v for i, v in enumerate(scheme["terminal"])})
    for polarity, roles in scheme["clearInk"].items():
        out.update({f"clearInk.{polarity}.{k}": v for k, v in roles.items()})
    return out


def _jobs():
    for case in harness.CASES["cases"]:
        if case.get("golden"):
            for variant in VARIANTS:
                for mode in MODES:
                    yield case, variant, mode


def test_golden_corpus():
    corpus = harness.corpus()
    update = os.environ.get("CHROMATIC_UPDATE_GOLDEN") == "1"
    strict = os.environ.get("CHROMATIC_GOLDEN_STRICT") == "1"

    def one(job):
        case, variant, mode = job
        rc, doc, _ = harness.run("generate", "--source", str(corpus / case["file"]), "--variant", variant,
                                 "--mode", mode)
        assert rc == 0, (case["name"], variant, mode, doc)
        return job, _normalise(doc, case)

    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(one, list(_jobs())))
    problems = []
    for (case, variant, mode), text in results:
        path = harness.GOLDEN / f"{case['name']}__{variant}__{mode}.json"
        if update:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            continue
        if not path.exists():
            problems.append(f"missing golden {path.name}")
            continue
        expected = path.read_text(encoding="utf-8")
        if expected == text:
            continue
        if strict:
            problems.append(f"{path.name}: bytes differ")
            continue
        want, got = json.loads(expected), json.loads(text)
        if want["engine"] != got["engine"] or want["inference"]["mode"] != got["inference"]["mode"] \
                or want["inference"]["variant"] != got["inference"]["variant"]:
            problems.append(f"{path.name}: engine/inference changed")
            continue
        a, b = _colours(want["scheme"]), _colours(got["scheme"])
        if set(a) != set(b):
            problems.append(f"{path.name}: role set changed")
            continue
        worst = max(math.dist(_oklab(a[k]), _oklab(b[k])) for k in a)
        if worst > 0.005:
            problems.append(f"{path.name}: colour moved by dEOK {worst:.4f} > 0.005")
    assert not problems, "\n".join(problems[:30])


def test_goldens_have_no_stale_files():
    expected = {f"{c['name']}__{v}__{m}.json" for c, v, m in _jobs()}
    present = {p.name for p in harness.GOLDEN.glob("*.json")}
    assert present == expected
