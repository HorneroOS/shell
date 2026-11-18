"""Shader-effect colour animation must register one interceptor per property.

Quickshell's ClippingRectangle forwards `color` to its shader's
`backgroundColor` (a ShaderEffect property). StyledClippingRect already puts
a Behavior on `color`; StateLayer declared a second one on its own
StyledClippingRect, so every hover layer logged
`Attempting to set another interceptor on QQuickShaderEffect_QML_* property
backgroundColor - unsupported` (shell 1.3.2: about 175 lines per start, each
one log-spam CPU cost). A hover layer now animates a plain ClippingRectangle.
"""
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

from chromatic_ui_harness import QS, ROOT, _strip_panel_windows, requires_qs

def _qml_files():
    skip = {"tests", ".git", "build", "docs"}
    for path in ROOT.rglob("*.qml"):
        if not skip & set(path.relative_to(ROOT).parts):
            yield path


def test_no_second_color_behavior_on_a_styled_clipping_rect():
    """StyledClippingRect already animates `color`; an instance (or a type
    rooted on it) must not declare another `Behavior on color`."""
    offenders = []
    for path in _qml_files():
        src = path.read_text()
        for m in re.finditer(r"\bStyledClippingRect\s*\{", src):
            depth, j = 1, m.end()
            while depth and j < len(src):
                depth += (src[j] == "{") - (src[j] == "}")
                j += 1
            block = src[m.end():j]
            for bm in re.finditer(r"Behavior on color", block):
                before = block[:bm.start()]
                if before.count("{") - before.count("}") == 0:  # direct child only
                    offenders.append(f"{path.relative_to(ROOT)}:{src[:m.start()].count(chr(10)) + 1}")
    assert not offenders, offenders


def test_state_layer_does_not_stack_a_behavior_on_styled_clipping_rect():
    src = (ROOT / "components/StateLayer.qml").read_text()
    assert "StyledClippingRect {" not in src
    assert "ClippingRectangle {" in src


def _run(tmp: Path) -> str:
    root = tmp / "root"

    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__", "assets"}]

    shutil.copytree(ROOT, root, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    os.symlink(ROOT / "assets", root / "assets")
    _strip_panel_windows(root)
    shutil.copy(ROOT / "tests/qml/shader_interceptors/harness.qml", root / "shell.qml")
    xdg = tmp / "xdg"
    for sub in ("config/hornero", "state/hornero", "data/hornero", "cache", "home", "rt"):
        (xdg / sub).mkdir(parents=True)
    (xdg / "rt").chmod(0o700)
    (xdg / "config/hornero/shell.json").write_text((ROOT / "config/shell.default.json").read_text())
    env = {
        "PATH": os.environ["PATH"],
        "XDG_CONFIG_HOME": str(xdg / "config"), "XDG_STATE_HOME": str(xdg / "state"),
        "XDG_DATA_HOME": str(xdg / "data"), "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_RUNTIME_DIR": str(xdg / "rt"), "HOME": str(xdg / "home"),
        "QML2_IMPORT_PATH": os.pathsep.join(filter(None, [str(root / "plugin" / "qml"), os.environ.get("HORNERO_PLUGIN_QML", "")])),
        "QT_QPA_PLATFORM": "offscreen", "LIBGL_ALWAYS_SOFTWARE": "1",
        "GIO_USE_VFS": "local", "GVFS_DISABLE_FUSE": "1",
    }
    try:
        proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
                              capture_output=True, text=True, timeout=120, env=env, cwd=tmp)
        out = proc.stdout + proc.stderr
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode(errors="replace") + (e.stderr or b"").decode(errors="replace")
    shutil.rmtree(root, ignore_errors=True)
    return re.sub(r"\x1b\[[0-9;]*m", "", out)


@requires_qs
def test_hover_layers_register_one_interceptor_per_shader_property(tmp_path):
    if shutil.which("dbus-run-session") is None:
        pytest.skip("NOT RUN: dbus-run-session is not installed")
    log = _run(tmp_path)
    assert "SHADER-DONE" in log, log[-3000:]
    bad = [ln for ln in log.splitlines() if "another interceptor" in ln]
    assert not bad, f"{len(bad)} warnings:\n" + "\n".join(bad[:5])
