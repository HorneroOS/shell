"""Offscreen Quickshell harness for the Chromatic UI tests.

Copies the shell tree into a scratch dir, strips the PanelWindow-backed
services that cannot load without a compositor, drops tests/qml/chromatic/
harness.qml in as shell.qml and runs `qs` with QT_QPA_PLATFORM=offscreen and
a fresh XDG tree. Never touches the real HOME or any user config. Skipped
(NOT RUN, never faked) when `qs` is not installed.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
QS = shutil.which("qs")

requires_qs = pytest.mark.skipif(not QS, reason="NOT RUN: quickshell (qs) is not installed")


def _strip_panel_windows(root: Path) -> None:
    for name in ("Notifs.qml", "IdleInhibitor.qml", "Experience.qml"):
        p = root / "services" / name
        t = p.read_text()
        t = re.sub(r"window: PanelWindow \{.*?\n        \}\n", "window: null\n", t, flags=re.S)
        t = t.replace("PanelWindow {", "Item {")
        t = re.sub(r'\n\s*color: "transparent"\n', "\n", t)
        t = re.sub(r"\n\s*mask: Region \{\}\n", "\n", t)
        p.write_text(t)


def build_root(dest: Path) -> Path:
    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__"}]

    shutil.copytree(ROOT, dest, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    _strip_panel_windows(dest)
    shutil.copy(ROOT / "tests" / "qml" / "chromatic" / "harness.qml", dest / "shell.qml")
    return dest


def xdg_digest(base: Path) -> dict:
    """Relative path -> (size, sha256) for every file under the XDG tree."""
    out = {}
    for p in sorted(base.rglob("*")):
        if p.is_file() and not p.is_symlink():
            out[str(p.relative_to(base))] = (p.stat().st_size, hashlib.sha256(p.read_bytes()).hexdigest())
    return out


def seed_xdg(base: Path) -> None:
    """A settled install: shell.json and a live scheme already exist, so a
    run that only previews has no reason to write anything."""
    cfg = base / "config" / "hornero"
    state = base / "state" / "hornero" / "signal"
    cfg.mkdir(parents=True)
    state.mkdir(parents=True)
    (base / "home").mkdir()
    (base / "data").mkdir()
    (base / "cache").mkdir()
    (cfg / "shell.json").write_text((ROOT / "config" / "shell.default.json").read_text())
    text = (ROOT / "services" / "Signal.qml").read_text()
    # The live scheme is Signal Night, generated from the built-in table.
    from signal_tokens import built_in_themes  # noqa: PLC0415

    night = built_in_themes()["hornero-signal-night"]
    (state / "scheme.json").write_text(json.dumps({
        "schemaVersion": 2, "id": night["id"], "mode": night["mode"],
        "palette": night["palette"], "terminal": night["terminal"]}, indent=2) + "\n")
    assert text  # the table above must stay in sync with Signal.qml


def run_scene(tmp_path: Path, scene: str, **env_extra) -> tuple[dict, dict, dict]:
    """Returns (result, tree_before, tree_after)."""
    root = build_root(tmp_path / "root")
    xdg = tmp_path / "xdg"
    seed_xdg(xdg)
    env = {
        "PATH": os.environ["PATH"],
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
        "HSCENE": scene,
    }
    env.update({k: str(v) for k, v in env_extra.items()})
    # Chromatic doubles: helper and horneroctl are fixtures, never the
    # user's binaries.
    fx = ROOT / "tests" / "fixtures" / "chromatic"
    bindir = tmp_path / "bin"
    bindir.mkdir(exist_ok=True)
    ctl = bindir / "horneroctl"
    if not ctl.exists():
        ctl.symlink_to(fx / "fake-horneroctl.sh")
    env["PATH"] = f"{bindir}:{env['PATH']}"
    env.setdefault("HORNERO_CHROMATIC_BIN", str(fx / "fake-helper.sh"))
    env.setdefault("FAKE_CTL_LOG", str(tmp_path / "ctl.log"))

    def launch(name: str) -> str:
        proc = subprocess.run(
            ["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"],
            capture_output=True, text=True, timeout=90, env=dict(env, HSCENE=name), cwd=tmp_path,
        )
        return proc.stdout + proc.stderr

    # First start of any install migrates/creates a few state files
    # (experience.json, ...). Let that settle, then compare only the run
    # under test.
    launch("idle")
    before = xdg_digest(xdg)
    log = launch(scene)
    lines = [ln for ln in log.splitlines() if "HRESULT " in ln]
    assert lines, f"harness produced no result:\n{log[-2000:]}"
    result = json.loads(lines[-1].split("HRESULT ", 1)[1])
    return result, before, xdg_digest(xdg)
