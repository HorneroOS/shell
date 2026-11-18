#!/usr/bin/env bash
# Lock-content frame-cost probe (see framecost-lock-harness.qml).
# Stages the lock module with the inert Pam stub so no real
# WlSessionLock can engage. Development-host measurement only.
# Kills only its own instance.
# Usage: tests/perf/run-framecost-lock.sh
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
scratch="$(mktemp -d)"
qpid=""
cleanup() {
    [[ -n "$qpid" ]] && kill "$qpid" 2>/dev/null || true
    rm -rf "$scratch"
}
trap cleanup EXIT

for d in assets components config services utils; do
    ln -sfn "$repo/$d" "$scratch/$d"
done
# Every module is linked (lock content imports siblings such as
# qs.modules.instruments, shell#653); only modules/lock is a private copy
# so the inert Pam stub can replace the real one.
mkdir -p "$scratch/modules"
for m in "$repo"/modules/*; do
    [[ "$(basename "$m")" == "lock" ]] && continue
    ln -sfn "$m" "$scratch/modules/$(basename "$m")"
done
cp -r "$repo/modules/lock" "$scratch/modules/lock"
cp "$repo/tests/atspi/lockstub/Pam.qml" "$scratch/modules/lock/Pam.qml"
cp "$repo/tests/perf/framecost-lock-harness.qml" "$scratch/shell.qml"

QT_ACCESSIBILITY=1 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 \
    qs -p "$scratch/shell.qml" >"$scratch/qs.log" 2>&1 &
qpid=$!
sleep 12
grep "FRAMECOST" "$scratch/qs.log" || { echo "FAIL: no FRAMECOST line"; cat "$scratch/qs.log"; exit 1; }
