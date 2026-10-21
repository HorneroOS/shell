#!/usr/bin/env bash
# AT-SPI runtime probe for the lock content surface.
#
# Stages a scratch Quickshell config where modules/lock is a copy
# of the repo module with Pam.qml replaced by the inert stub in
# lockstub/ (the real Pam needs a WlSessionLock; a probe must never
# lock the session), then checks that the password field and the
# Unlock button reach the AT-SPI tree with their names.
#
# Needs a running Wayland session. Not wired into CI.
# Usage: tests/atspi/run-lock-probe.sh
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
mkdir -p "$scratch/modules"
cp -r "$repo/modules/lock" "$scratch/modules/lock"
cp "$repo/tests/atspi/lockstub/Pam.qml" "$scratch/modules/lock/Pam.qml"
cp "$repo/tests/atspi/lock-harness.qml" "$scratch/shell.qml"

QT_ACCESSIBILITY=1 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1 \
    qs -p "$scratch/shell.qml" >"$scratch/qs.log" 2>&1 &
qpid=$!
sleep 8

out="$(python3 "$repo/tests/atspi/probe.py")"
echo "$out"
grep -q "Password" <<<"$out" || { echo "FAIL: Password field not in AT-SPI tree"; exit 1; }
grep -q "Unlock" <<<"$out" || { echo "FAIL: Unlock button not in AT-SPI tree"; exit 1; }
echo "PASS: lock content exposes Password + Unlock"
