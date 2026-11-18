#!/usr/bin/env python3
"""Spectrum CPU probe: old Repeater spectrum vs SpectrumMeter.

Runs tests/perf/spectrum/harness.qml offscreen with the `qml` runtime and
reads the process CPU time (utime + stime from /proc/<pid>/stat) over a
fixed window, a few trials per case, and prints the median CPU %.

    run-spectrum-cpu.py --old-import <qml dir of the old plugin build>
                        --new-import <qml dir of this branch's build>
                        [--trials 3] [--window 20] [--warmup 4] [--json out]

`--backend software` forces the Qt Quick software renderer (CPU raster,
what an offscreen session without GPU gets); `--backend gpu` renders with
the real GPU through an offscreen OpenGL pbuffer (needs a GLX display, shows
no window). Development-host measurement (no compositor); kills only
its own children. Heavy: run it through the host's resource-capped wrapper.
"""

import argparse
import json
import os
import shutil
import statistics
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
TICK = os.sysconf("SC_CLK_TCK")


def cpu_seconds(pid):
    fields = Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()
    return (int(fields[11]) + int(fields[12])) / TICK


def trial(qml, import_path, impl, scenario, bands, warmup, window, scratch, parts="both", backend="software"):
    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QT_FORCE_STDERR_LOGGING="1", QML_IMPORT_PATH=import_path, QML2_IMPORT_PATH=import_path)
    if backend == "gpu":
        # Real GPU through an offscreen GL pbuffer: no window is shown.
        env.update(QT_QUICK_BACKEND="rhi", QSG_RHI_BACKEND="opengl")
    else:
        env.update(QT_QUICK_BACKEND="software")
    log = scratch / f"{impl}-{scenario}.log"
    with log.open("w") as fh:
        proc = subprocess.Popen([qml, str(HERE / "harness.qml"), "--", impl, scenario, str(bands), parts],
                                stdout=fh, stderr=subprocess.STDOUT, env=env)
    try:
        deadline = time.monotonic() + 15
        while "SPECTRUM_PROBE_READY" not in log.read_text(errors="replace"):
            if proc.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError(f"harness did not start: {log.read_text(errors='replace')[-2000:]}")
            time.sleep(0.2)
        time.sleep(warmup)
        c0, t0 = cpu_seconds(proc.pid), time.monotonic()
        time.sleep(window)
        c1, t1 = cpu_seconds(proc.pid), time.monotonic()
        return 100.0 * (c1 - c0) / (t1 - t0)
    finally:
        proc.terminate()
        try:
            proc.wait(5)
        except subprocess.TimeoutExpired:
            proc.kill()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--old-import", required=True)
    ap.add_argument("--new-import", required=True)
    ap.add_argument("--trials", type=int, default=3)
    ap.add_argument("--window", type=float, default=20)
    ap.add_argument("--warmup", type=float, default=4)
    ap.add_argument("--bands", type=int, default=45)
    ap.add_argument("--scratch", default=None)
    ap.add_argument("--json", default=None)
    ap.add_argument("--scenarios", default="idle,play")
    ap.add_argument("--backend", default="software", choices=["software", "gpu"])
    ap.add_argument("--parts", default="both", help="both | well | desktop")
    a = ap.parse_args()
    qml = shutil.which("qml6") or shutil.which("qml")
    if not qml:
        sys.exit("needs the Qt 6 `qml` runtime")
    scratch = Path(a.scratch or os.environ.get("XDG_RUNTIME_DIR", "."), "spectrum-cpu")
    scratch.mkdir(parents=True, exist_ok=True)
    rows = []
    for scenario in a.scenarios.split(","):
        for impl, path in (("old", a.old_import), ("new", a.new_import)):
            runs = [trial(qml, path, impl, scenario, a.bands, a.warmup, a.window, scratch, a.parts, a.backend) for _ in range(a.trials)]
            rows.append({"impl": impl, "scenario": scenario, "runs": runs, "median": statistics.median(runs)})
            print(f"{scenario:<5} {impl:<4} median {statistics.median(runs):6.2f} %  runs {['%.2f' % r for r in runs]}", flush=True)
    if a.json:
        Path(a.json).write_text(json.dumps({"backend": a.backend, "parts": a.parts, "bands": a.bands, "window_s": a.window, "trials": a.trials, "rows": rows}, indent=2))


if __name__ == "__main__":
    main()
