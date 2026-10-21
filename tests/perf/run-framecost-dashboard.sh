#!/usr/bin/env bash
# Dashboard frame-cost probe (see framecost-dashboard-harness.qml).
# Development-host measurement only. Kills only its own instance.
# Usage: tests/perf/run-framecost-dashboard.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
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
cp "$repo/tests/perf/framecost-dashboard-harness.qml" "$scratch/shell.qml"

QT_ACCESSIBILITY=1 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 \
    qs -p "$scratch/shell.qml" >"$scratch/qs.log" 2>&1 &
qpid=$!
sleep 14
grep "FRAMECOST" "$scratch/qs.log" || { echo "FAIL: no FRAMECOST line"; cat "$scratch/qs.log"; exit 1; }
