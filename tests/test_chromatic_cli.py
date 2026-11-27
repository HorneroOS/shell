"""hornero-chromatic helper contract: verbs, JSON shapes, exit codes (RFC 0002 §10.1)."""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "chromatic"))
import harness  # noqa: E402

ROLES = ("ground sunken base panel raised lifted ink inkMuted inkFaint rule ruleStrong signal onSignal "
         "signalWell onSignalWell cue onCue cueWell onCueWell phosphor onPhosphor phosphorWell onPhosphorWell "
         "alert onAlert alertWell onAlertWell inverse onInverse inverseSignal scrim shadow focus").split()
HEX = re.compile(r"^#[0-9A-F]{6}$")


def test_version_and_variants():
    rc, doc, _ = harness.run("version")
    assert rc == 0
    assert doc["schemaVersion"] == 1 and doc["engine"]["name"] == "hornero-chromatic"
    assert doc["algorithm"] == doc["engine"]["algorithm"] >= 1
    assert "png" in doc["formats"] and "jpeg" in doc["formats"]
    rc, doc, _ = harness.run("variants")
    assert rc == 0
    assert [v["id"] for v in doc["variants"]] == harness.VARIANTS
    assert [v["id"] for v in doc["variants"] if v["darkOnly"]] == ["neon"]


def test_generate_seed_shape():
    rc, doc, _ = harness.run("generate", "--seed", "#D98A3A")
    assert rc == 0
    assert set(doc) == {"schemaVersion", "engine", "request", "analysis", "inference", "scheme", "gates",
                        "adjustments", "fingerprint"}
    assert doc["analysis"] is None
    scheme = doc["scheme"]
    assert scheme["id"] == "hornero-chromatic" and scheme["schemaVersion"] == 2
    assert set(ROLES) <= set(scheme["palette"]) <= set(ROLES) | {"glow"}
    assert all(HEX.match(v) for v in scheme["palette"].values())
    assert len(scheme["terminal"]) == 16 and all(HEX.match(v) for v in scheme["terminal"])
    assert scheme["chromatic"]["fingerprint"] == doc["fingerprint"].lower() == doc["fingerprint"]
    assert doc["fingerprint"].startswith("sha256:")
    assert set(scheme["clearInk"]) == {"light", "dark"}
    for polarity in scheme["clearInk"].values():
        assert set(polarity) == {"ink", "inkMuted", "signal", "alert", "halo"}
    assert set(scheme["minSurfaceAlpha"]) == {"sunken", "base", "panel", "raised", "lifted"}
    assert doc["gates"]["passed"] is True and doc["gates"]["rows"]
    assert "path" not in scheme["chromatic"]["request"]
    assert "surfaceTint" not in scheme["chromatic"]["request"]


def test_surface_tint_flag_and_backward_compatibility():
    _, auto_doc, _ = harness.run("generate", "--seed", "#D98A3A", "--surface-tint", "auto")
    assert "surfaceTint" not in auto_doc["scheme"]["chromatic"]["request"]
    _, neutral_doc, _ = harness.run("generate", "--seed", "#B73C6E", "--variant", "vibrant", "--surface-tint", "neutral")
    assert neutral_doc["scheme"]["chromatic"]["request"]["surfaceTint"] == "neutral"
    _, tinted_doc, _ = harness.run("generate", "--seed", "#B73C6E", "--variant", "balanced", "--surface-tint", "tinted")
    assert tinted_doc["scheme"]["chromatic"]["request"]["surfaceTint"] == "tinted"
    assert neutral_doc["scheme"]["palette"]["panel"] != tinted_doc["scheme"]["palette"]["panel"]
    rc, err_doc, _ = harness.run("generate", "--seed", "#D98A3A", "--surface-tint", "bogus")
    assert rc == 2 and err_doc["error"]["code"] == "usage"


def test_light_mode_has_no_glow_and_neon_is_dark_only():
    _, light, _ = harness.run("generate", "--seed", "#3A7FD9", "--mode", "light")
    assert light["scheme"]["mode"] == "light" and "glow" not in light["scheme"]["palette"]
    _, neon, _ = harness.run("generate", "--seed", "#3A7FD9", "--mode", "light", "--variant", "neon")
    assert neon["scheme"]["mode"] == "dark"
    assert any("dark only" in r for r in neon["inference"]["reasons"])


def test_usage_errors_exit_2():
    for args in (["generate"], ["generate", "--seed", "nothex"], ["generate", "--seed", "#000000", "--chroma", "3"],
                 ["generate", "--seed", "#000000", "--variant", "tonal"], ["frobnicate"], ["analyze"],
                 ["generate", "--seed", "#000000", "--house"]):
        rc, doc, _ = harness.run(*args)
        assert rc == 2, args
        assert doc["error"]["code"] == "usage"


def test_unreadable_exit_3(tmp_path):
    empty = tmp_path / "empty.png"
    empty.write_bytes(b"")
    for path in (empty, tmp_path / "missing.png"):
        rc, doc, _ = harness.run("generate", "--source", str(path))
        assert rc == 3
        assert doc["error"]["code"] == "source-unreadable"


def test_validate_verb(tmp_path):
    _, doc, _ = harness.run("generate", "--seed", "#D98A3A")
    good = tmp_path / "scheme.json"
    good.write_text(json.dumps(doc["scheme"]))
    rc, report, _ = harness.run("validate", "--scheme", str(good))
    assert rc == 0 and report["passed"] is True and report["chromaticExtra"] is True
    bad = dict(doc["scheme"], palette=dict(doc["scheme"]["palette"], ink=doc["scheme"]["palette"]["base"]))
    (tmp_path / "bad.json").write_text(json.dumps(bad))
    rc, report, _ = harness.run("validate", "--scheme", str(tmp_path / "bad.json"))
    assert rc == 0 and report["passed"] is False
    (tmp_path / "junk.json").write_text("{")
    rc, _, _ = harness.run("validate", "--scheme", str(tmp_path / "junk.json"))
    assert rc == 2


def test_request_file_and_flags_override(tmp_path):
    req = tmp_path / "req.json"
    req.write_text(json.dumps({"source": "seed", "seeds": ["#3A7FD9"], "variant": "muted", "follow": "auto"}))
    _, a, _ = harness.run("generate", "--request", str(req))
    assert a["inference"]["variant"] == "muted"
    _, b, _ = harness.run("generate", "--request", str(req), "--variant", "vibrant")
    assert b["inference"]["variant"] == "vibrant"


def test_cache_equals_no_cache(tmp_path):
    src = harness.case_path("split-complement")
    _, cold, _ = harness.run("generate", "--source", str(src))
    cache = tmp_path / "cache"
    _, first, out1 = harness.run("generate", "--source", str(src), cache=cache)
    _, second, out2 = harness.run("generate", "--source", str(src), cache=cache)
    assert list((cache / "analysis").iterdir())
    assert out1 == out2
    assert cold["scheme"] == first["scheme"] and cold["fingerprint"] == second["fingerprint"]


def test_corrupt_cache_entry_is_replaced(tmp_path):
    src = harness.case_path("skin")
    cache = tmp_path / "cache"
    _, first, _ = harness.run("generate", "--source", str(src), cache=cache)
    for entry in (cache / "analysis").iterdir():
        entry.write_text('{"digest":"sha256:0","analysis":{"algorithm":1}}')
    rc, second, _ = harness.run("generate", "--source", str(src), cache=cache)
    assert rc == 0 and second["fingerprint"] == first["fingerprint"]


def test_changed_file_same_size_is_detected(tmp_path):
    """Path, size and mtime never key the cache alone (RFC §15)."""
    import os
    import shutil
    a, b = harness.case_path("red-dominant"), harness.case_path("green-dominant")
    target = tmp_path / "wall.png"
    shutil.copy(a, target)
    cache = tmp_path / "cache"
    _, first, _ = harness.run("generate", "--source", str(target), cache=cache)
    stat = target.stat()
    data = b.read_bytes()
    target.write_bytes(data)
    os.utime(target, ns=(stat.st_atime_ns, stat.st_mtime_ns))
    _, second, _ = harness.run("generate", "--source", str(target), cache=cache)
    assert first["fingerprint"] != second["fingerprint"]


def test_analyze_shape():
    rc, doc, _ = harness.run("analyze", "--source", str(harness.case_path("gif-anim")))
    assert rc == 0
    assert set(doc) == {"schemaVersion", "engine", "source", "analysis", "inference"}
    assert doc["analysis"]["kind"] == "animated"
    assert 1 <= len(doc["analysis"]["seeds"]) <= 5
