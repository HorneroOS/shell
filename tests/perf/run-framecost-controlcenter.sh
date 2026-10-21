#!/usr/bin/env bash
# Control Center frame-cost probe (see
# framecost-controlcenter-harness.qml). Development-host
# measurement only. Kills only its own instance.
# Usage: tests/perf/run-framecost-controlcenter.sh
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
cp "$repo/tests/perf/framecost-controlcenter-harness.qml" "$scratch/shell.qml"

QT_ACCESSIBILITY=1 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 \
    qs -p "$scratch/shell.qml" >"$scratch/qs.log" 2>&1 &
qpid=$!
sleep 12
grep "FRAMECOST" "$scratch/qs.log" || { echo "FAIL: no FRAMECOST line"; cat "$scratch/qs.log"; exit 1; }
