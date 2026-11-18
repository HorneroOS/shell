"""Machined fillets (signal-visual-language §7.1, border.fillet).

Policy (components/placement/Fillet.js) runs under node; wiring is checked
statically; the real frame, drawer backgrounds and popout frame are rendered
offscreen by tests/qml/fillets/harness.qml when quickshell is installed
(skipped, never faked, otherwise). FILLET_SHOTS=<dir> keeps the renders.
FILLET_GOLDEN_TREE=<checkout of main> also renders that tree with fillet 0
and requires every scene to be pixel-identical (fillet 0 = the flush look).
"""
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from chromatic_ui_harness import _strip_panel_windows

ROOT = Path(__file__).resolve().parent.parent
JS = ROOT / "components" / "placement" / "Fillet.js"
QS = shutil.which("qs")
NODE = shutil.which("node")


def run_js(body: str):
    src = JS.read_text(encoding="utf-8").replace(".pragma library", "")
    out = subprocess.run(["node", "-e", src + "\n" + body], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


@pytest.mark.skipif(NODE is None, reason="node not installed")
def test_policy_radius():
    r = run_js("""console.log(JSON.stringify([
        radius(6, false, true, true), radius(6, false, true, false), radius(6, false, false, true),
        radius(6, false, false, false), radius(6, true, true, true), radius(0, false, true, true),
        radius(40, false, true, true), radius(-3, false, true, true), radius(NaN, false, true, true)]))""")
    # attached bar + frame, frame only, bar only, bare screen edge (Cockpit
    # Clear sides), floating/clear bar, setting 0, clamp high, clamp low, junk.
    assert r == [6, 6, 6, 0, 0, 0, 16, 0, 0]


@pytest.mark.skipif(NODE is None, reason="node not installed")
def test_policy_rule_and_fit():
    r = run_js("""console.log(JSON.stringify([
        rule(true, true, false, 1), rule(true, false, true, 1), rule(true, false, true, 4),
        rule(false, true, false, 1), rule(false, false, false, 1), rule(true, true, false, 0),
        fit(6, 180, 3, 0.5), fit(6, 9, 3, 0.5), fit(6, 2, 3, 0.5), fit(0, 180, 3, 0.5), fit(6, 180, 3, -0.5)]))""")
    assert r == [0.5, 1, 2, -0.5, 0, 0, 6, 5.5, 0, 0, 6]


def test_setting_is_a_customisable_range_with_reset():
    cfg = (ROOT / "config" / "BorderConfig.qml").read_text()
    assert "property int fillet: 6" in cfg
    assert json.loads((ROOT / "config" / "shell.default.json").read_text())["border"]["fillet"] == 6
    assert "fillet: border.fillet" in (ROOT / "config" / "Config.qml").read_text()
    ranges = json.loads((ROOT / "config" / "ranges.json").read_text())["ranges"]
    assert ranges["border.fillet"] == {"min": 0, "max": 16, "step": 1, "default": 6}
    section = (ROOT / "modules/controlcenter/appearance/sections/BorderSection.qml").read_text()
    block = section[section.index('key: "fillet"') - 200:section.index('key: "fillet"') + 300]
    assert "SizeSlider" in block and 'qsTr("Machined fillet")' in block and "defaultValue: 6" in block


def test_every_attached_sheet_takes_a_fillet():
    bgs = (ROOT / "modules/drawers/Backgrounds.qml").read_text()
    for edge in ("top", "bottom", "right"):
        assert f'root.bar.filletOn("{edge}")' in bgs and f'root.bar.filletRule("{edge}")' in bgs
    for mod in ("dashboard", "launcher", "osd", "session", "sidebar", "utilities"):
        src = (ROOT / "modules" / mod / "Background.qml").read_text()
        assert "property real fillet: 0" in src, mod
        assert "Fillet.fit(" in src, mod
        # The rule stroke is one path: fillet arcs live in the same ShapePath.
        assert src.count("ShapePath {") == 1, mod
    barset = (ROOT / "modules/bar/BarSet.qml").read_text()
    assert "Fillet.radius(Config.border.fillet, root.openOn(edge), root.frameVisible" in barset
    panels = (ROOT / "modules/drawers/Panels.qml").read_text()
    assert "fillet: root.bar.filletOn(popouts.edge)" in panels
    frame = (ROOT / "components/placement/SurfaceFrame.qml").read_text()
    assert "visible: !root._filleted" in frame and "_filleted: attached && fillet > 0" in frame


# ---- offscreen renders ----

def _build(src: Path, dest: Path) -> Path:
    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__", "assets"}]

    shutil.copytree(src, dest, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    os.symlink(src / "assets", dest / "assets")
    _strip_panel_windows(dest)
    # The harness feeds stub panels: let the backgrounds take any Item.
    for p in list((dest / "modules").glob("*/Background.qml")) + [dest / "modules/drawers/Backgrounds.qml"]:
        t = p.read_text()
        t = t.replace("required property Wrapper wrapper", "required property Item wrapper")
        t = t.replace("required property Panels panels", "required property Item panels")
        p.write_text(t)
    # Trees without fillets (golden) still need the harness's policy module.
    target = dest / "components/placement/Fillet.js"
    if not target.exists():
        shutil.copy(JS, target)
    shutil.copy(ROOT / "tests/qml/fillets/harness.qml", dest / "shell.qml")
    return dest


def _render(tree: Path, tmp: Path, out: Path, force0: bool = False) -> list:
    root = _build(tree, tmp / "root")
    xdg = tmp / "xdg"
    for sub in ("config/hornero", "state/hornero", "data/hornero", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    (xdg / "config/hornero/shell.json").write_text((tree / "config/shell.default.json").read_text())
    out.mkdir(parents=True, exist_ok=True)
    env = {
        "PATH": os.environ["PATH"],
        "XDG_CONFIG_HOME": str(xdg / "config"), "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"), "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"), "HOME": str(xdg / "home"),
        "QML2_IMPORT_PATH": os.pathsep.join(filter(None, [str(root / "plugin" / "qml"), os.environ.get("HORNERO_PLUGIN_QML", "")])),
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1", "FL_OUT": str(out),
        # No gvfs fuse mount inside the throwaway runtime dir.
        "GIO_USE_VFS": "local", "GVFS_DISABLE_FUSE": "1",
    }
    if force0:
        env["FL_FORCE0"] = "1"
    proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                          capture_output=True, text=True, timeout=180, env=env, cwd=tmp)
    log = re.sub(r"\x1b\[[0-9;]*m", "", proc.stdout + proc.stderr)
    (out / "harness.log").write_text(log)
    lines = [ln for ln in log.splitlines() if "FILLET " in ln]
    assert lines, f"harness never reported:\n{log[-3000:]}"
    return json.loads(lines[-1].split("FILLET ", 1)[1])


@pytest.fixture(scope="module")
def renders(tmp_path_factory):
    if not QS or shutil.which("dbus-run-session") is None:
        pytest.skip("NOT RUN: quickshell (qs) or dbus-run-session is not installed")
    base = tmp_path_factory.mktemp("fillets")
    shots = Path(os.environ["FILLET_SHOTS"]) if os.environ.get("FILLET_SHOTS") else base / "shots"
    report = _render(ROOT, base / "branch", shots)
    return {r["name"]: r for r in report}, shots, base


def _f(report, scene, sheet):
    return report[scene]["backgrounds"][sheet]["f"]


@pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")
def test_attached_sheets_draw_the_configured_fillet(renders):
    report, _, _ = renders
    for sheet in ("dashboard", "launcher", "osd", "utilities"):
        assert _f(report, "top-attached-f6", sheet) == 6, sheet
        assert _f(report, "top-attached-f16", sheet) == 16, sheet
        assert _f(report, "top-attached-f0", sheet) == 0, sheet
    for scene in ("bottom-attached-f6", "left-attached-f6", "right-attached-f6", "noframe-top-attached-f6"):
        assert _f(report, scene, "dashboard") == 6, scene
    assert report["top-attached-f6"]["popout"]["fillet"] == 6
    assert report["left-attached-f6"]["popout"]["fillet"] == 6
    assert report["right-attached-f6"]["popout"]["edge"] == "right"


@pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")
def test_floating_clear_and_bare_edges_stay_flush(renders):
    report, _, _ = renders
    # A floating top bar: the dashboard keeps its breathing gap, no fillet;
    # the frame-backed sheets keep theirs.
    assert _f(report, "top-floating-f6", "dashboard") == 0
    assert _f(report, "top-floating-f6", "launcher") == 6
    assert report["top-floating-f6"]["popout"]["fillet"] == 0
    # Cockpit Clear: no frame, clear bars top and bottom, bare sides.
    for sheet in ("dashboard", "launcher", "osd", "utilities"):
        assert _f(report, "cockpit-clear-f6", sheet) == 0, sheet


@pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")
def test_fillet_follows_the_outline_and_the_opening_sheet(renders):
    report, _, _ = renders
    assert report["top-attached-f6"]["backgrounds"]["dashboard"]["c"] == 0.5
    assert report["top-attached-hc-f6"]["backgrounds"]["dashboard"]["c"] == 1
    assert report["noframe-top-attached-f6"]["backgrounds"]["dashboard"]["c"] == -0.5
    # A 9 px tall opening sheet (radius 3, rule 0.5) gets at most 5.5 px.
    assert _f(report, "top-attached-opening-f6", "dashboard") == 5.5


@pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")
def test_fillet_changes_only_the_junctions(renders):
    Image = pytest.importorskip("PIL.Image")
    ImageChops = pytest.importorskip("PIL.ImageChops")
    _, shots, _ = renders
    a = Image.open(shots / "top-attached-f0.png").convert("RGB")
    b = Image.open(shots / "top-attached-f6.png").convert("RGB")
    diff = ImageChops.difference(a, b)
    box = diff.getbbox()
    assert box, "fillet 6 drew nothing"
    # Changed pixels sit within fillet + 2 px of a junction corner.
    corners = []
    W, H, T, F = 1280, 800, 40, 10
    dash_x0, dash_x1 = (W - 520) / 2, (W + 520) / 2
    corners += [(dash_x0, T), (dash_x1, T)]
    corners += [((W - 460) / 2, H - F), ((W + 460) / 2, H - F)]
    corners += [(W - F, (T + H - F) / 2 - 100), (W - F, (T + H - F) / 2 + 100)]
    corners += [(W - F - 300, H - F), (W - F, H - F - 150)]
    corners += [(110, T), (110 + 220, T)]
    px = diff.load()
    stray = []
    for y in range(box[1], box[3]):
        for x in range(box[0], box[2]):
            if sum(px[x, y]) > 24 and not any(abs(x - cx) <= 8 and abs(y - cy) <= 8 for cx, cy in corners):
                stray.append((x, y))
    assert not stray, stray[:20]


@pytest.mark.skipif(not os.environ.get("FILLET_GOLDEN_TREE"), reason="set FILLET_GOLDEN_TREE to a main checkout")
def test_fillet_zero_is_pixel_identical_to_the_flush_look(renders):
    Image = pytest.importorskip("PIL.Image")
    ImageChops = pytest.importorskip("PIL.ImageChops")
    report, _, base = renders
    golden = Path(os.environ["FILLET_GOLDEN_TREE"])
    gshots = base / "golden-shots"
    bshots = base / "branch0-shots"
    _render(golden, base / "golden", gshots, force0=True)
    _render(ROOT, base / "branch0", bshots, force0=True)
    bad = []
    for name in report:
        a = Image.open(gshots / f"{name}.png").convert("RGBA")
        b = Image.open(bshots / f"{name}.png").convert("RGBA")
        # The utilities sheet is the one intended change at fillet 0: its
        # old path closed with a diagonal (half the sheet missing).
        for im in (a, b):
            im.paste((0, 0, 0, 0), (1280 - 10 - 300 - 4, 0, 1280, 800))
        box = ImageChops.difference(a, b).getbbox()
        if box is not None:
            bad.append((name, box))
    assert bad == []


@pytest.mark.skipif(QS is None, reason="NOT RUN: quickshell (qs) is not installed")
def test_utilities_sheet_is_a_whole_rectangle(renders):
    Image = pytest.importorskip("PIL.Image")
    _, shots, _ = renders
    im = Image.open(shots / "top-attached-f0.png").convert("RGB")
    # Inside the sheet near its bottom-right and its top-left corners: the
    # same panel fill (the old path filled only the upper-left triangle).
    a = im.getpixel((1280 - 10 - 20, 800 - 10 - 20))
    b = im.getpixel((1280 - 10 - 280, 800 - 10 - 130))
    assert max(abs(x - y) for x, y in zip(a, b)) <= 2, (a, b)
