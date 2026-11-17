"""Shared harness for the Hornero Chromatic pytest suites.

The helper and the corpus generator are C++ build outputs. Point the tests
at them with environment variables (the CI `build` job does):

    HORNERO_CHROMATIC_BIN      path to the built `hornero-chromatic`
    HORNERO_CHROMATIC_CORPUS   path to the built `chromatic-corpus`
    HORNERO_CONFIG_DIR         optional HorneroOS/config checkout (validator)

Without them every engine test skips with a reason, so the plain `tests`
job (Python only) stays meaningful.
"""
from __future__ import annotations

import functools
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
GOLDEN = ROOT / "tests" / "chromatic" / "golden"
CASES = json.loads((ROOT / "tests" / "chromatic" / "cases.json").read_text(encoding="utf-8"))
VARIANTS = ["balanced", "vibrant", "expressive", "faithful", "muted", "monochrome", "high-contrast", "neon"]
LEVELS = ["standard", "boosted", "maximum"]


def helper() -> str:
    path = os.environ.get("HORNERO_CHROMATIC_BIN")
    if not path or not os.access(path, os.X_OK):
        pytest.skip("HORNERO_CHROMATIC_BIN not set to a built hornero-chromatic")
    return path


@functools.lru_cache(maxsize=1)
def _scratch() -> Path:
    base = os.environ.get("HORNERO_CHROMATIC_SCRATCH")
    root = Path(base) if base else Path(tempfile.mkdtemp(prefix="hornero-chromatic-tests-"))
    root.mkdir(parents=True, exist_ok=True)
    return root


def isolated_env() -> dict[str, str]:
    """Environment with every XDG dir inside the scratch tree."""
    root = _scratch() / "xdg"
    env = dict(os.environ)
    for key in ("XDG_CONFIG_HOME", "XDG_STATE_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME"):
        d = root / key.lower()
        d.mkdir(parents=True, exist_ok=True)
        env[key] = str(d)
    env["HOME"] = str(root / "home")
    return env


@functools.lru_cache(maxsize=1)
def corpus() -> Path:
    gen = os.environ.get("HORNERO_CHROMATIC_CORPUS")
    if not gen or not os.access(gen, os.X_OK):
        pytest.skip("HORNERO_CHROMATIC_CORPUS not set to a built chromatic-corpus")
    out = _scratch() / "corpus"
    if out.exists():
        shutil.rmtree(out)
    subprocess.run([gen, str(out)], check=True, env=isolated_env(), timeout=120)
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg:
        subprocess.run([ffmpeg, "-nostdin", "-v", "error", "-f", "lavfi", "-i",
                        "testsrc2=size=320x180:rate=10:duration=2", "-c:v", "libvpx-vp9", "-y",
                        str(out / "video.webm")], check=False, timeout=60)
    return out


def run(*args: str, cache: Path | None = None, check_json: bool = True) -> tuple[int, dict | None, str]:
    cmd = [helper(), *args]
    if cache is None and args and args[0] in ("generate", "analyze"):
        cmd.append("--no-cache")
    elif cache is not None:
        cmd += ["--cache-dir", str(cache)]
    proc = subprocess.run(cmd, capture_output=True, text=True, env=isolated_env(), timeout=60)
    doc = None
    if proc.stdout.strip():
        doc = json.loads(proc.stdout)
    elif check_json:
        raise AssertionError(f"no JSON on stdout: {cmd}\n{proc.stderr}")
    return proc.returncode, doc, proc.stdout


def case_path(name: str) -> Path:
    case = next(c for c in CASES["cases"] if c["name"] == name)
    return corpus() / case["file"]


@functools.lru_cache(maxsize=1)
def config_validator():
    """config's signal_theme.py from HORNERO_CONFIG_DIR, or None."""
    base = os.environ.get("HORNERO_CONFIG_DIR")
    if not base:
        return None
    path = Path(base) / "lib" / "hornero" / "signal_theme.py"
    if not path.is_file():
        return None
    spec = importlib.util.spec_from_file_location("hornero_signal_theme", path)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(module)
    return module


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()
