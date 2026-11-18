"""Experience pane header must not be painted over by neighbouring panes (shell#650).

Control Center keeps the active pane and its immediate neighbours loaded in
one tall stack. Customisation sits directly above Experience; its list
Flickable did not clip, so its rows ("Bar > Clear ink > Polarity", Edit,
Reset) painted over the top of the Experience pane. The offscreen render
compares the Experience header strip with and without the Customisation pane
visible: it must be identical. Static contracts always run; the render needs
`qs` and Pillow and is skipped, never faked, without them.
"""
import copy
import json
import os
import subprocess
from pathlib import Path

import pytest

from chromatic_ui_harness import QS, ROOT, build_root, requires_qs, seed_xdg

CC = ROOT / "modules" / "controlcenter"
PANES = (CC / "Panes.qml").read_text()
CUSTOM = (CC / "customisation" / "CustomisationPane.qml").read_text()


def test_every_pane_in_the_stack_clips_to_its_own_viewport():
    pane = PANES.split("component Pane: Item {", 1)[1].split("Loader {", 1)[0]
    assert "clip: true" in pane, "neighbour panes must never paint outside their page"


def test_customisation_list_flickable_clips():
    flick = CUSTOM.split("StyledFlickable {", 1)[1].split("ColumnLayout {", 1)[0]
    assert "clip: true" in flick


def test_customisation_precedes_experience_so_the_overflow_hits_its_header():
    registry = (CC / "PaneRegistry.qml").read_text()
    order = [line.split('"')[1] for line in registry.splitlines() if "readonly property string label:" in line]
    assert order.index("experience") == order.index("customisation") + 1


def _customised_config() -> dict:
    cfg = json.loads((ROOT / "config" / "shell.default.json").read_text())
    out = copy.deepcopy(cfg)
    out.setdefault("clearInk", {})["polarity"] = "dark"
    flipped = 0

    def flip(node):
        nonlocal flipped
        if isinstance(node, dict):
            for k, v in node.items():
                if isinstance(v, bool) and flipped < 40:
                    node[k] = not v
                    flipped += 1
                else:
                    flip(v)

    for section in ("bar", "appearance", "border", "general"):
        if section in out:
            flip(out[section])
    return out


def _plain_clipping_rectangles(root: Path) -> None:
    """Quickshell's ClippingRectangle is a shader effect that paints nothing
    under the software GL offscreen platform. Swap it for a clipping
    Rectangle in the throwaway copy so the pane stack is visible; the
    overlap under test is plain Item clipping, not the shader."""
    import re  # noqa: PLC0415

    for qml in (root / "modules" / "controlcenter").rglob("*.qml"):
        text = qml.read_text()
        if "ClippingRectangle" not in text:
            continue
        text = re.sub(
            r"\bClippingRectangle \{\n",
            lambda m: "Rectangle {\n" + ("" if "clip:" in text[m.end():m.end() + 400] else "        clip: true\n"),
            text,
        )
        text = text.replace("border.innerRadius", "radius")
        text = text.replace("import Quickshell.Widgets\n", "")
        qml.write_text(text)


def run_scene(tmp_path: Path):
    root = build_root(tmp_path / "root")
    _plain_clipping_rectangles(root)
    (root / "shell.qml").write_text((ROOT / "tests" / "qml" / "experience_overlap" / "harness.qml").read_text())
    xdg = tmp_path / "xdg"
    seed_xdg(xdg)
    (xdg / "config" / "hornero" / "shell.json").write_text(json.dumps(_customised_config(), indent=2))
    fx = ROOT / "tests" / "fixtures" / "chromatic"
    bindir = tmp_path / "bin"
    bindir.mkdir(exist_ok=True)
    (bindir / "horneroctl").symlink_to(fx / "fake-horneroctl.sh")
    env = {
        "PATH": f"{bindir}:{os.environ['PATH']}",
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": os.environ.get("XDG_RUNTIME_DIR", str(tmp_path)),
        "HOME": str(xdg / "home"),
        "USER": "operator",
        "LOGNAME": "operator",
        "QT_QPA_PLATFORM": "offscreen",
        "LIBGL_ALWAYS_SOFTWARE": "1",
        "QSG_RHI_BACKEND": "opengl",
        "HOUT_A": str(tmp_path / "a.png"),
        "HOUT_B": str(tmp_path / "b.png"),
        "FAKE_CTL_LOG": str(tmp_path / "ctl.log"),
    }
    env["HOUT_A"] = os.environ.get("HOUT_A", env["HOUT_A"])
    env["HOUT_B"] = os.environ.get("HOUT_B", env["HOUT_B"])
    proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                          capture_output=True, text=True, timeout=120, env=env, cwd=tmp_path)
    log = proc.stdout + proc.stderr
    lines = [ln for ln in log.splitlines() if "HRESULT " in ln]
    assert lines, f"harness produced no result:\n{log[-3000:]}"
    return json.loads(lines[-1].split("HRESULT ", 1)[1]), Path(env["HOUT_A"]), Path(env["HOUT_B"])


@requires_qs
def test_offscreen_experience_header_is_not_overpainted(tmp_path):
    Image = pytest.importorskip("PIL.Image")
    ImageChops = pytest.importorskip("PIL.ImageChops")
    result, a, b = run_scene(tmp_path)
    assert result["activePane"] == "experience" and result["experienceLoaded"]
    assert result["customisationLoaded"], "the warm neighbour is what leaks; it must be loaded"
    assert result["customisedRows"] >= 5, "the scene needs a tall customised list"
    ia, ib = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
    assert ia.size == ib.size
    # Header + intro strip of the Experience pane (top of the window).
    box = (0, 0, ia.width, 170)
    diff = ImageChops.difference(ia.crop(box), ib.crop(box)).getbbox()
    assert diff is None, f"a neighbouring pane paints over the Experience header: {diff}"
