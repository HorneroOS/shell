#!/usr/bin/env python3
"""Graphical smoke runner: launch the shell under Quickshell and screenshot it.

Requires a live Wayland session (WAYLAND_DISPLAY), qs and grim.
Without one it prints NOT RUN and exits 77 — it never fabricates a PASS.
Usage: run_gui_smoke.py <output-dir>
"""
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def main() -> int:
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    if not os.environ.get("WAYLAND_DISPLAY") or not shutil.which("qs") or not shutil.which("grim"):
        print("NOT RUN: no Wayland session / qs / grim (headless screenshots unsupported here)")
        return 77
    out_dir.mkdir(parents=True, exist_ok=True)
    proc = subprocess.Popen(
        ["qs", "-p", str(ROOT / "shell.qml")],
        stdout=(out_dir / "qs.log").open("w"), stderr=subprocess.STDOUT,
    )
    try:
        time.sleep(8)
        if proc.poll() is not None:
            print(f"FAIL: qs exited early rc={proc.returncode}; see {out_dir}/qs.log")
            return 1
        shot = subprocess.run(["grim", str(out_dir / "shell.png")],
                              capture_output=True, text=True, timeout=30)
        if shot.returncode != 0 or not (out_dir / "shell.png").stat().st_size:
            print(f"FAIL: grim screenshot failed: {shot.stderr[:300]}")
            return 1
        print(f"PASS: screenshot captured at {out_dir}/shell.png")
        return 0
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()


if __name__ == "__main__":
    raise SystemExit(main())
