"""Rack rhythm spacing and the Compact / Cosy / Airy density presets.

Signal visual language §7.1 rack rhythm: 8 inside a module, 12 between
modules, 16 surface inset, 24 section break. The dashboard home grid and
the bar popouts take every gap and inset from the spacing/padding tokens,
so Appearance > Scales > Density moves them together. The render checks
open the real dashboard offscreen at each density and look for text that
paints outside its instrument frame or the screen. Skipped, never faked,
without quickshell.
"""
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from chromatic_ui_harness import QS, ROOT, _strip_panel_windows

DASH = ROOT / "modules" / "dashboard" / "Dash.qml"
FRAME = ROOT / "modules" / "instruments" / "Frame.qml"
POPOUTS = sorted((ROOT / "modules" / "bar" / "popouts").rglob("*.qml"))
SCALES = ROOT / "modules" / "controlcenter" / "appearance" / "sections" / "ScalesSection.qml"

# A spacing, margin or padding property set to a bare number.
LITERAL = re.compile(r"\b(spacing|rowSpacing|columnSpacing|[A-Za-z]*[Mm]argins?|[A-Za-z]*[Pp]adding)\s*:\s*(-?\d+(?:\.\d+)?)\b")
# Allowed literals, each with its reason: 0 means "no gap" (a flush stack
# or a page that carries its own inset), not a step of the rhythm.
ALLOWED = {"0"}


def literals(path: Path) -> list[str]:
    out = []
    for n, line in enumerate(path.read_text().splitlines(), 1):
        code = line.split("//", 1)[0]
        for m in LITERAL.finditer(code):
            if m.group(2) not in ALLOWED:
                out.append(f"{path.relative_to(ROOT)}:{n}: {line.strip()}")
    return out


def test_dashboard_grid_uses_the_between_module_step():
    t = DASH.read_text()
    assert "rowSpacing: Appearance.spacing.normal" in t
    assert "columnSpacing: Appearance.spacing.normal" in t


def test_no_literal_spacing_in_dashboard_and_popouts():
    bad = [b for p in [DASH, *POPOUTS] for b in literals(p)]
    assert not bad, "literal spacing (use a token):\n" + "\n".join(bad)


def test_dashboard_heights_are_token_sums():
    t = DASH.read_text()
    assert not re.search(r"implicitHeight:\s*\d+\s*$", t, re.M), "fixed frame height; derive it from content + tokens"
    assert not re.search(r"\+\s*\d+\s*$", t, re.M), "literal spacing added to a height"


def test_instrument_frame_inset_and_header_are_tokens():
    t = FRAME.read_text()
    assert "property int padding: Appearance.padding.large" in t
    assert "anchors.topMargin: Appearance.spacing.normal" in t
    assert "Appearance.spacing.normal + Appearance.spacing.smaller" in t
    assert not literals(FRAME)


def test_density_presets_write_both_scales_with_cosy_default():
    t = SCALES.read_text()
    scales = dict(re.findall(r'id: "(compact|cosy|airy)",\s*label: qsTr\("\w+"\),\s*scale: ([\d.]+)', t))
    assert scales == {"compact": "0.75", "cosy": "1.0", "airy": "1.25"}
    assert "rootPane.spacingScale = d.scale" in t and "rootPane.paddingScale = d.scale" in t
    assert 'qsTr("Reset density")' in t and "root.applyDensity(1)" in t
    cfg = json.loads((ROOT / "config" / "shell.default.json").read_text())["appearance"]
    assert cfg["spacing"]["scale"] == 1 and cfg["padding"]["scale"] == 1


def render(tmp: Path, scale: float, w: int, h: int, out: Path | None = None, mode: str = "layout", anim: dict | None = None, reduced: bool = False) -> dict:
    tag = "DASH " if mode == "layout" else "DASHMOTION "
    root = tmp / "root"

    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__", "assets"}]

    shutil.copytree(ROOT, root, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    os.symlink(ROOT / "assets", root / "assets")
    _strip_panel_windows(root)
    shutil.copy(ROOT / "tests" / "qml" / "dashboard" / "harness.qml", root / "shell.qml")
    xdg = tmp / "xdg"
    for sub in ("config/hornero", "state/hornero", "data/hornero", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    cfg = json.loads((ROOT / "config" / "shell.default.json").read_text())
    cfg["appearance"]["spacing"]["scale"] = scale
    cfg["appearance"]["padding"]["scale"] = scale
    cfg["appearance"]["anim"].update(anim or {})
    cfg["appearance"]["reducedMotion"] = reduced
    (xdg / "config" / "hornero" / "shell.json").write_text(json.dumps(cfg))
    env = {
        "PATH": os.environ["PATH"],
        "XDG_CONFIG_HOME": str(xdg / "config"), "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"), "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"), "HOME": str(xdg / "home"),
        "QML2_IMPORT_PATH": os.pathsep.join(filter(None, [str(root / "plugin" / "qml"), os.environ.get("HORNERO_PLUGIN_QML", "")])),
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1",
        "DS_W": str(w), "DS_H": str(h), "DS_MODE": mode,
    }
    if out:
        env["DS_OUT"] = str(out)
    proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                          capture_output=True, text=True, timeout=120, env=env, cwd=tmp)
    log = re.sub(r"\x1b\[[0-9;]*m", "", proc.stdout + proc.stderr)
    shutil.rmtree(root, ignore_errors=True)
    lines = [ln for ln in log.splitlines() if tag in ln]
    assert lines, f"harness never reported:\n{log[-2500:]}"
    return json.loads(lines[-1].split(tag, 1)[1])


# The default Cockpit pair reserves 42 + 28 px. Compact is the 768p preset
# (it fits there); every density must fit 1080p and 1440p.
BARS = 42 + 28


@pytest.mark.skipif(not QS, reason="NOT RUN: quickshell (qs) is not installed")
@pytest.mark.parametrize("scale,w,h", [(0.75, 1366, 768), (1.0, 1920, 1080), (1.25, 1920, 1080), (1.25, 2560, 1440)])
def test_dashboard_renders_at_each_density_without_clipping(tmp_path, scale, w, h):
    ev = os.environ.get("RACK_EVIDENCE_DIR")
    out = Path(ev) / f"dashboard-{scale:.2f}-{w}x{h}.png" if ev else None
    r = render(tmp_path, scale, w, h, out)
    assert r["spacingScale"] == pytest.approx(scale) and r["paddingScale"] == pytest.approx(scale)
    assert r["frames"] >= 6, r
    gap = round(12 * scale)
    assert [gap, gap] in r["grids"], r["grids"]
    sw, sh = r["size"]
    assert sw <= w and sh <= h - BARS, f"dashboard {r['size']} does not fit {w}x{h} under the default bars"
    assert not r["issues"], r["issues"]
