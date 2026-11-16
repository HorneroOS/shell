#!/usr/bin/env bash
# Anchored-surface probe (see anchored-surface-harness.qml): input to
# first frame for open/switch, worst frame interval while animating, and
# scene-graph render-thread cost per frame from QSG_RENDER_TIMING.
# Development-host measurement only (needs a Wayland session). Kills only
# its own instance.
# Usage: tests/perf/run-anchored-surface.sh [full|standard|reduced|off]
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
level="${1:-standard}"
scratch="$(mktemp -d)"
qpid=""
cleanup() {
    [[ -n "$qpid" ]] && kill "$qpid" 2>/dev/null || true
    rm -rf "$scratch"
}
trap cleanup EXIT

for d in assets components config services utils modules; do
    ln -sfn "$repo/$d" "$scratch/$d"
done
sed "s/^ShellRoot {/ShellRoot {\n    Component.onCompleted: Choreography.modeLevel = \"${level}\"/" \
    "$repo/tests/perf/anchored-surface-harness.qml" >"$scratch/shell.qml"

QSG_RENDER_TIMING=1 QT_MESSAGE_PATTERN='%{category} %{message}' \
    qs -p "$scratch/shell.qml" >"$scratch/qs.log" 2>&1 &
qpid=$!
for _ in $(seq 1 90); do
    grep -q "ANCHORED done" "$scratch/qs.log" && break
    sleep 1
done
grep "ANCHORED" "$scratch/qs.log" || { echo "FAIL: no ANCHORED lines"; tail -40 "$scratch/qs.log"; exit 1; }
# Render-thread cost per frame: "render=" (ms) of every rendered frame.
python3 - "$scratch/qs.log" <<'PY'
import re, statistics, sys
text = open(sys.argv[1], errors="replace").read()
lat = {}
for kind, ms in re.findall(r"ANCHORED latency kind=(\w+) ms=([\d.]+)", text):
    lat.setdefault(kind, []).append(float(ms))
frames = []
for line in text.splitlines():
    if "Frame rendered" in line or "Frame prepared" in line:
        parts = dict(re.findall(r"(\w+)=([\d.]+)", line))
        total = re.search(r" in ([\d.]+)ms", line)
        frames.append({k: float(v) for k, v in parts.items()} | ({"total": float(total.group(1))} if total else {}))
def stats(vals):
    vals = sorted(vals)
    if not vals:
        return "n=0"
    p95 = vals[min(len(vals) - 1, int(len(vals) * 0.95))]
    return f"n={len(vals)} mean={statistics.mean(vals):.2f} p95={p95:.2f} max={vals[-1]:.2f}"
for kind, vals in lat.items():
    print(f"RESULT latency {kind}: {stats(vals)} ms")
for key in ("total", "sync", "render", "swap"):
    vals = [f[key] for f in frames if key in f]
    if vals:
        print(f"RESULT frame {key}: {stats(vals)} ms")
PY
