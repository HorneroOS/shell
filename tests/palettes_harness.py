"""Offscreen run of tests/qml/palettes/harness.qml in an isolated XDG tree.

Reuses the Chromatic harness plumbing (shell copy without PanelWindow
services, fresh XDG dirs, fixture helper). Skipped, never faked, when `qs`
is missing.
"""
import json
import os
import subprocess
from pathlib import Path

from chromatic_ui_harness import QS, ROOT, build_root, requires_qs, seed_xdg  # noqa: F401


def run_gallery(tmp_path: Path, helper: str | None = None, png: Path | None = None, theme: str = "hornero-signal-night", **extra_env) -> dict:
    root = build_root(tmp_path / "root")
    (root / "shell.qml").write_text((ROOT / "tests" / "qml" / "palettes" / "harness.qml").read_text())
    xdg = tmp_path / "xdg"
    seed_xdg(xdg)
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
        "HORNERO_CHROMATIC_BIN": helper or str(fx / "fake-helper.sh"),
        "FAKE_LOG": str(tmp_path / "helper.log"),
        "HTHEME": theme,
    }
    env.update({k: str(v) for k, v in extra_env.items()})
    env.setdefault("FAKE_CTL_LOG", str(tmp_path / "ctl.log"))
    if png:
        env["HOUT"] = str(png)
    proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"], capture_output=True, text=True, timeout=120, env=env, cwd=tmp_path)
    log = proc.stdout + proc.stderr
    lines = [ln for ln in log.splitlines() if "HRESULT " in ln]
    assert lines, f"harness produced no result:\n{log[-3000:]}"
    result = json.loads(lines[-1].split("HRESULT ", 1)[1])
    result["_helper_log"] = (tmp_path / "helper.log").read_text() if (tmp_path / "helper.log").exists() else ""
    result["_ctl_log"] = (tmp_path / "ctl.log").read_text() if (tmp_path / "ctl.log").exists() else ""
    result["_draft"] = next(iter((xdg / "state" / "hornero" / "shell" / "theme-draft").glob("*.json")), None)
    result["_draft"] = json.loads(result["_draft"].read_text()) if result["_draft"] else None
    result["_log"] = log
    return result
