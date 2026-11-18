"""Offscreen run of tests/qml/appearance/harness.qml (the REAL Appearance pane).

Reuses the Chromatic harness plumbing (shell copy without PanelWindow
services, fresh XDG dirs, fixture horneroctl and helper). Skipped, never
faked, when `qs` is missing. Can be pointed at another checkout with
`shell_root` (used to capture a "before" render of an older tree).
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

from chromatic_ui_harness import QS, ROOT, _strip_panel_windows, requires_qs, seed_xdg  # noqa: F401

HARNESS = ROOT / "tests" / "qml" / "appearance" / "harness.qml"


def _flatten_clipping(root: Path) -> None:
    """The software-GL offscreen grab draws nothing under Quickshell's
    ClippingRectangle (shader clip) or InnerBorder's MultiEffect mask, so the
    harness copy swaps them for a plain clipped Rectangle / an unmasked
    border. Only the copy is changed; layout and every pane item are real."""
    split = root / "modules" / "controlcenter" / "components" / "SplitPaneLayout.qml"
    t = split.read_text().replace("ClippingRectangle {", "Rectangle {\n            clip: true")
    split.write_text(t)
    border = root / "components" / "effects" / "InnerBorder.qml"
    border.write_text(border.read_text().replace("layer.enabled: true\n    layer.effect", "layer.enabled: false\n    layer.effect").replace("color: Signal.tPalette.panel", "color: \"transparent\""))


def _copy_shell(src: Path, dest: Path) -> Path:
    def ignore(_dir, names):
        return [n for n in names if n in {".git", "tests", "docs", "build", "__pycache__"}]

    shutil.copytree(src, dest, ignore=ignore, symlinks=True, ignore_dangling_symlinks=True)
    _strip_panel_windows(dest)
    _flatten_clipping(dest)
    (dest / "shell.qml").write_text(HARNESS.read_text())
    return dest


def run_pane(tmp_path: Path, scene: str = "idle", png: Path | None = None, shell_root: Path | None = None, with_wallpaper: bool = True, **extra_env) -> dict:
    root = _copy_shell(shell_root or ROOT, tmp_path / "root")
    xdg = tmp_path / "xdg"
    seed_xdg(xdg)
    if scene == "preview-variant":
        # Chromatic from one colour: needs no wallpaper, so the scene runs
        # the same on a bare CI container as on a desktop, and with
        # whichever engine is installed (in-process module, packaged
        # helper or the fixture helper).
        cfg_path = xdg / "config" / "hornero" / "shell.json"
        cfg = json.loads(cfg_path.read_text())
        cfg["appearance"]["chromatic"]["source"] = "seed"
        cfg["appearance"]["chromatic"]["seeds"] = ["#D98A3A"]
        cfg_path.write_text(json.dumps(cfg, indent=2) + "\n")
    fx = ROOT / "tests" / "fixtures" / "chromatic"
    bindir = tmp_path / "bin"
    bindir.mkdir(exist_ok=True)
    # A settled wallpaper: the pointer file plus `horneroctl wallpaper
    # current`; every other horneroctl call goes to the Chromatic fixture.
    # `with_wallpaper=False` reproduces a bare container (CI shell-load).
    walls = Path("/usr/share/hornero/wallpapers")
    wall = next(iter(sorted(walls.rglob("*.jpg"))), None) if with_wallpaper and walls.is_dir() else None
    if wall:
        ptr = xdg / "state" / "hornero" / "wallpaper"
        ptr.mkdir(parents=True, exist_ok=True)
        (ptr / "path").write_text(f"{wall}\n")
    ctl = bindir / "horneroctl"
    ctl.write_text(
        "#!/usr/bin/env bash\n"
        f'if [ "$1 $2" = "wallpaper current" ]; then echo "{wall or ""}"; exit 0; fi\n'
        f'exec "{fx / "fake-horneroctl.sh"}" "$@"\n'
    )
    ctl.chmod(0o755)
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
        "HORNERO_CHROMATIC_BIN": str(fx / "fake-helper.sh"),
        "FAKE_LOG": str(tmp_path / "helper.log"),
        "FAKE_CTL_LOG": str(tmp_path / "ctl.log"),
        "HSCENE": scene,
    }
    env.update({k: str(v) for k, v in extra_env.items()})
    if png:
        env["HOUT"] = str(png)
    proc = subprocess.run(["dbus-run-session", "--", QS, "-p", str(root), "--no-duplicate"], capture_output=True, text=True, timeout=150, env=env, cwd=tmp_path)
    log = proc.stdout + proc.stderr
    lines = [ln for ln in log.splitlines() if "HRESULT " in ln]
    assert lines, f"harness produced no result:\n{log[-3000:]}"
    result = json.loads(lines[-1].split("HRESULT ", 1)[1])
    result["_log"] = log
    result["_ctl_log"] = (tmp_path / "ctl.log").read_text() if (tmp_path / "ctl.log").exists() else ""
    return result


if __name__ == "__main__":  # manual evidence capture
    import sys

    out = Path(sys.argv[1])
    scene = sys.argv[2] if len(sys.argv) > 2 else "idle"
    shell = Path(sys.argv[3]) if len(sys.argv) > 3 else None
    work = out.parent / f".work-{out.stem}"
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)
    res = run_pane(work, scene=scene, png=out, shell_root=shell)
    res.pop("_log")
    print(json.dumps(res, indent=2))
    shutil.rmtree(work)
