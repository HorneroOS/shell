"""Raster master ingestion: registry contract and pixel gates."""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import companion_masters as cm  # noqa: E402


def _entry(tmp_path, **over):
    f = tmp_path / "idle.png"
    f.write_bytes(b"x")
    e = {"id": "idle", "file": "idle.png", "sha256": hashlib.sha256(b"x").hexdigest(),
         "pose": "idle", "anchor": "feet", "pivot": [512, 900], "origin": "vector"}
    e.update(over)
    return e


def test_registry_loads_and_checks_clean():
    assert isinstance(cm.load_registry(), list)
    assert cm.check() == 0


def test_hash_pin_mismatch_fails(tmp_path):
    e = _entry(tmp_path, sha256="0" * 64)
    assert any("sha256" in m for m in cm.validate_entry(e, tmp_path, check_pixels=False))


def test_external_requires_provenance(tmp_path):
    e = _entry(tmp_path, origin="external")
    errs = cm.validate_entry(e, tmp_path, check_pixels=False)
    assert {"tool", "prompt", "date", "licence"} <= {m.split("provenance.")[1] for m in errs if "provenance." in m}
    e["provenance"] = {"tool": "t", "prompt": "p", "date": "2026-11-17", "licence": "owned"}
    assert not cm.validate_entry(e, tmp_path, check_pixels=False)


def test_unknown_pose_and_anchor(tmp_path):
    errs = cm.validate_entry(_entry(tmp_path, pose="dance", anchor="head"), tmp_path, check_pixels=False)
    assert len(errs) == 2


def test_pixel_gates(tmp_path):
    pil = pytest.importorskip("PIL.Image")
    im = pil.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    for x in range(300, 700):
        for y in range(200, 900):
            im.putpixel((x, y), (160, 90, 40, 255))
    good = tmp_path / "ok.png"
    im.save(good)
    e = _entry(tmp_path, file="ok.png", sha256=cm.sha256(good))
    assert not cm.validate_entry(e, tmp_path)
    bg = pil.new("RGBA", (1024, 1024), (30, 30, 30, 255))
    p = tmp_path / "bg.png"
    bg.save(p)
    errs = cm.validate_entry(_entry(tmp_path, file="bg.png", sha256=cm.sha256(p)), tmp_path)
    assert any("transparent" in m or "border" in m for m in errs)
    small = tmp_path / "s.png"
    pil.new("RGBA", (256, 256), (0, 0, 0, 0)).save(small)
    errs = cm.validate_entry(_entry(tmp_path, file="s.png", sha256=cm.sha256(small)), tmp_path)
    assert any("long side" in m for m in errs)
