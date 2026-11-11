"""Companion production assets: manifest contract, frame validation, drift.

Stdlib only (struct/zlib PNG decode): runs in CI without Pillow.
Deterministic re-derivation gates (--check) run when Pillow is present.
"""
from __future__ import annotations

import json
import struct
import subprocess
import sys
import zlib
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
COMPANION = ROOT / "assets" / "companion"
FRAMES = COMPANION / "frames"
MANIFEST = COMPANION / "manifest.json"
PREVIEW = COMPANION / "preview"

SKINS = ("default", "argentina", "blue-gold", "red", "gaucho",
         "nocturnal", "retro-terminal", "mono")
EXPECTED_ANIM = {
    "idle": {"nframes": 4, "anchor": "feet"},
    "blink": {"nframes": 3, "anchor": "feet"},
    "look": {"nframes": 3, "anchor": "feet"},
    "preen": {"nframes": 6, "anchor": "feet"},
    "stretch": {"nframes": 4, "anchor": "feet"},
    "hop": {"nframes": 4, "anchor": "feet"},
    "greet": {"nframes": 4, "anchor": "feet"},
    "walk": {"nframes": 6, "anchor": "feet"},
    "hover": {"nframes": 4, "anchor": "center"},
    "takeoff": {"nframes": 3, "anchor": "feet"},
    "fly": {"nframes": 6, "anchor": "center"},
    "land": {"nframes": 3, "anchor": "feet"},
    "perch": {"nframes": 2, "anchor": "feet"},
    "peek": {"nframes": 1, "anchor": "feet"},
    "drag": {"nframes": 1, "anchor": "center"},
    "talk": {"nframes": 4, "anchor": "feet"},
    "think": {"nframes": 4, "anchor": "feet"},
    "listen": {"nframes": 2, "anchor": "feet"},
    "work": {"nframes": 4, "anchor": "feet"},
    "approve": {"nframes": 4, "anchor": "feet"},
    "celebrate": {"nframes": 6, "anchor": "feet"},
    "deny": {"nframes": 3, "anchor": "feet"},
    "worry": {"nframes": 2, "anchor": "feet"},
    "error": {"nframes": 3, "anchor": "feet"},
    "sleep": {"nframes": 4, "anchor": "feet"},
}
ANIMATIONS = tuple(EXPECTED_ANIM)


def read_png(path: Path):
    """Return (width, height, alpha_bytes) for 8-bit RGBA/palette PNGs."""
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{path} not a PNG"
    pos, w, h, ctype = 8, None, None, None
    raw = b""
    trns = b""
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype_raw = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if ctype_raw == b"IHDR":
            w, h, depth, ctype, _, _, _ = struct.unpack(">IIBBBBB", body)
            assert depth == 8, f"{path} bit depth {depth}"
            assert ctype in (3, 6), f"{path} color type {ctype} (need RGBA/palette)"
        elif ctype_raw == b"tRNS":
            trns = body
        elif ctype_raw == b"IDAT":
            raw += body
        pos += 12 + length
    assert w is not None
    bpp = 4 if ctype == 6 else 1
    px = zlib.decompress(raw)
    stride = w * bpp
    alpha = bytearray()
    prev = bytearray(stride)
    p = 0
    for _ in range(h):
        f = px[p]
        p += 1
        line = bytearray(px[p:p + stride])
        p += stride
        if f == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 0xFF
        elif f == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif f == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 0xFF
        elif f == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                q = a + b - c
                pa, pb, pc = abs(q - a), abs(q - b), abs(q - c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 0xFF
        elif f != 0:
            raise AssertionError(f"{path} unknown filter {f}")
        if ctype == 6:
            alpha.extend(line[3::4])
        else:
            alpha.extend(trns[v] if v < len(trns) else 255 for v in line)
        prev = line
    return w, h, bytes(alpha)


@pytest.fixture(scope="module")
def manifest():
    return json.loads(MANIFEST.read_text())


def test_manifest_version_and_shape(manifest):
    assert manifest["manifestVersion"] == 2
    assert manifest["canvas"] == {"width": 512, "height": 512}
    assert manifest["baseline"] == {"feetY": 472, "flyCenter": [256, 256]}
    assert manifest["anchors"] == {"feet": [256, 472], "center": [256, 256]}
    assert sorted(manifest["nests"]) == ["cup", "dome", "home", "none", "twigs"]
    assert sorted(manifest["skins"]) == sorted(SKINS)
    for skin in SKINS:
        entry = manifest["skins"][skin]
        assert entry["fallbackChain"][-1] == "default"
        assert sorted(entry["animations"]) == sorted(ANIMATIONS)
        for anim, want in EXPECTED_ANIM.items():
            a = entry["animations"][anim]
            assert a["id"] == anim
            assert len(a["frames"]) == want["nframes"]
            assert a["anchor"] == want["anchor"]
            assert isinstance(a["frameMs"], int) and a["frameMs"] > 0
            assert isinstance(a["loop"], bool)
            assert a["next"] in ANIMATIONS
            for frame in a["frames"]:
                assert frame["file"].startswith("frames/")
                assert len(frame["size"]) == 2
                assert len(frame["offset"]) == 2
                assert len(frame["anchorPx"]) == 2


def test_every_skin_ships_its_own_fly(manifest):
    # Reboot: poses are authored once and recolored per skin, so no
    # skin flies as the bare default bird any more.
    for skin in SKINS:
        fly = manifest["skins"][skin]["animations"]["fly"]["frames"][0]
        assert fly["file"].startswith(f"frames/{skin}-fly-"), fly["file"]
        assert manifest["skins"][skin]["fallbackChain"][-1] == "default"
    assert manifest["assistantStates"] == {
        "resting": "idle",
        "listening": "listen",
        "thinking": "think",
        "acting": "work",
        "speaking": "talk",
        "success": "approve",
        "warning": "worry",
        "denied": "deny",
        "error": "error",
    }


def test_frames_exist_real_transparency_no_checkerboard():
    files = sorted(FRAMES.glob("*.png"))
    per_skin = sum(v["nframes"] for v in EXPECTED_ANIM.values())
    assert len(files) == per_skin * len(SKINS) + 5, \
        f"expected {per_skin * len(SKINS) + 5} frames, got {len(files)}"
    for path in files:
        w, h, alpha = read_png(path)
        assert (w, h) == (512, 512), f"{path.name} canvas {(w, h)}"
        n = len(alpha)
        lo, hi = min(alpha), max(alpha)
        assert lo == 0, f"{path.name} has no transparent pixel (min {lo})"
        assert hi >= 200, f"{path.name} max alpha {hi}"
        opaque = sum(1 for v in alpha if v == 255) / n
        clear = sum(1 for v in alpha if v == 0) / n
        # Flat vector art is mostly solid inside the silhouette; the
        # checkerboard guard is the alpha-extrema check above.
        assert opaque < 0.40, f"{path.name} {opaque:.2%} fully opaque"
        assert clear > 0.05, f"{path.name} only {clear:.2%} transparent"


def test_canvas_baseline_drift():
    """Feet-anchored frames share one baseline; fly shares one center."""
    manifest = json.loads(MANIFEST.read_text())
    seen = set()
    for skin, entry in manifest["skins"].items():
        for anim, a in entry["animations"].items():
            for frame in a["frames"]:
                key = frame["file"]
                ox, oy = frame["offset"]
                fw, fh = frame["size"]
                ax, ay = frame["anchorPx"]
                if a["anchor"] == "feet":
                    # Grounded frames end at the baseline; hop/land
                    # transition frames may sit above it, never below.
                    # peek is a deliberate partial-body slice running
                    # off the bottom edge.
                    if anim != "peek":
                        assert 380 <= oy + fh <= 472, f"{key} feet {oy + fh}"
                    assert ax == 256 and ay == 472, f"{key} anchor {ax, ay}"
                else:
                    assert [ox + fw / 2, oy + fh / 2] == pytest.approx(
                        [256, 256], abs=24.0), f"{key} center drift"
                seen.add((skin, key))
    # every skin x animation resolves to a real committed file
    for _, key in seen:
        assert (COMPANION / key).is_file(), f"missing {key}"


def test_no_personal_paths_or_markers():
    text = MANIFEST.read_text()
    assert "/home/" not in text and "ulises" not in text.lower()
    assert "{{" not in text
    qml = (ROOT / "modules" / "companion" / "Companion.qml").read_text()
    assert "/home/" not in qml and "{{" not in qml


def test_contact_sheets_committed():
    for name in ("preview-default-animations.png", "preview-skins.png",
                 "preview-assistant-states.png", "preview-nests.png"):
        path = PREVIEW / name
        assert path.is_file(), f"missing sheet {name}"
        w, h, _ = read_png(path)
        assert w > 0 and h > 0


def test_qml_resolver_present():
    qml = ROOT / "modules" / "companion" / "Companion.qml"
    assert qml.is_file()
    text = qml.read_text()
    for token in ("resolve(", "frameSource(", "stateSource(", "fallbackChain",
                  "manifest.json", "FileView"):
        assert token in text, f"Companion.qml missing {token}"


def _needs_pil():
    try:
        import PIL  # noqa: F401
    except ImportError:
        pytest.skip("Pillow not installed")


def test_derive_check():
    _needs_pil()
    # Without an SVG renderer the script falls back to a structural
    # gate (manifest/frames/SVG masters agree); pixel drift stays
    # gated wherever a renderer exists.
    proc = subprocess.run([sys.executable, "scripts/derive-companion-assets.py",
                           "--check"], cwd=ROOT, capture_output=True, text=True,
                          timeout=300)
    assert proc.returncode == 0, proc.stderr


def test_pixel_fingerprint_ignores_encoder_bytes(tmp_path):
    """Re-encoded PNGs with identical pixels must not read as drift.

    PNG bytes and resampling results vary between Pillow releases;
    the drift gate tolerates that noise so CI and authoring machines
    agree, while a real content change (a painted block standing in
    for a pose/skin edit) must still read as drift.
    """
    _needs_pil()
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "derive_companion_assets", ROOT / "scripts" / "derive-companion-assets.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    from PIL import Image, ImageDraw

    frame = Image.open(FRAMES / "red-idle-01.png").convert("RGBA")
    a = tmp_path / "a.png"
    b = tmp_path / "b.png"
    frame.save(a, optimize=True)
    frame.save(b, optimize=False, compress_level=0)
    assert a.read_bytes() != b.read_bytes()  # encoder bytes really differ
    assert not module._drifted(a, b)

    noisy = frame.copy()
    px = noisy.load()
    for x in range(0, noisy.width, 7):  # sparse ±1 resampler-style noise
        for y in range(0, noisy.height, 7):
            r, g, bl, al = px[x, y]
            px[x, y] = (min(r + 1, 255), g, bl, al)
    n = tmp_path / "n.png"
    noisy.save(n, optimize=True)
    assert not module._drifted(a, n)

    tampered = frame.copy()
    ImageDraw.Draw(tampered).rectangle([100, 100, 180, 180], fill=(255, 0, 0, 255))
    c = tmp_path / "c.png"
    tampered.save(c, optimize=True)
    assert module._drifted(a, c)


def test_preview_check():
    _needs_pil()
    proc = subprocess.run(["scripts/preview-companion-assets", "--check"],
                          cwd=ROOT, capture_output=True, text=True, timeout=300)
    assert proc.returncode == 0, proc.stderr
