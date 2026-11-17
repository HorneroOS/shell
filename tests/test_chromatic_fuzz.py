"""Corrupted and adversarial inputs never crash the decoders (RFC 0002 §15).

Every mutation must end with exit 0 (decoded) or 3 (source-unreadable),
never a signal, a hang or another code.
"""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "chromatic"))
import harness  # noqa: E402


def _mutations(data: bytes, rng: random.Random):
    for cut in sorted({rng.randrange(1, len(data)) for _ in range(12)}):
        yield f"truncate@{cut}", data[:cut]
    for i in range(18):
        buf = bytearray(data)
        for _ in range(rng.randrange(1, 24)):
            buf[rng.randrange(0, len(buf))] = rng.randrange(256)
        yield f"flip#{i}", bytes(buf)
    yield "header-only", data[:32]
    yield "doubled", data + data


def test_mutated_sources_exit_cleanly(tmp_path):
    rng = random.Random(0xC0FFEE)
    corpus = harness.corpus()
    bad = []
    for name in ("jpeg-ref.jpg", "noise.png", "gif-anim.gif", "png16.png", "p3-jpeg.jpg"):
        data = (corpus / name).read_bytes()
        for label, payload in _mutations(data, rng):
            target = tmp_path / f"m-{label}-{name}"
            target.write_bytes(payload)
            rc, doc, _ = harness.run("analyze", "--source", str(target))
            if rc not in (0, 3) or (rc == 3 and doc["error"]["code"] != "source-unreadable"):
                bad.append(f"{name} {label}: exit {rc}")
            target.unlink()
    assert not bad, "\n".join(bad)


def test_wrong_extension_and_directory(tmp_path):
    png = (harness.corpus() / "noise.png").read_bytes()
    disguised = tmp_path / "picture.jpg"
    disguised.write_bytes(png)
    rc, _, _ = harness.run("analyze", "--source", str(disguised))
    assert rc == 0  # format comes from content
    rc, doc, _ = harness.run("analyze", "--source", str(tmp_path))
    assert rc == 3 and doc["error"]["code"] == "source-unreadable"
    text = tmp_path / "notes.png"
    text.write_text("not an image\n")
    rc, _, _ = harness.run("analyze", "--source", str(text))
    assert rc == 3
