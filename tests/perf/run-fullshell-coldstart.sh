#!/usr/bin/env bash
# Full-shell cold-start probe: launch the checkout shell as a
# second instance and time until the bar's Volume control reaches
# the AT-SPI tree (first interactive surface). Development-host
# measurement only; the release gate needs the disposable QA
# harness. Never signals any pre-existing Quickshell process: it
# only kills the instance it started, by PID.
#
# Refuses to run while the packaged session is locked.
# Usage: tests/perf/run-fullshell-coldstart.sh [runs]
set -euo pipefail

repo="$(cd "$(dirname "$0")/../.." && pwd)"
runs="${1:-3}"

locked="$(QS_CONFIG_PATH=/etc/xdg/quickshell/hornero/shell.qml qs ipc call lock isLocked 2>/dev/null || echo unknown)"
if [[ "$locked" == "true" ]]; then
    echo "FAIL: session is locked; not starting a second shell" >&2
    exit 1
fi

export QT_ACCESSIBILITY=1 QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1
for i in $(seq 1 "$runs"); do
    start=$(date +%s%3N)
    qs >"/tmp/qs-coldstart-$i.log" 2>&1 &
    qpid=$!
    found=no
    for _ in $(seq 1 100); do
        if python3 "$repo/tests/atspi/probe.py" 2>/dev/null | grep -q "Volume controls"; then
            found=yes
            break
        fi
        sleep 0.2
    done
    end=$(date +%s%3N)
    echo "run$i: $((end - start)) ms (bar-in-atspi=$found)"
    kill "$qpid" 2>/dev/null || true
    wait "$qpid" 2>/dev/null || true
    sleep 2
done
