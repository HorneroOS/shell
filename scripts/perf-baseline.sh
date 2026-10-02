#!/usr/bin/env bash
# Repeatable desktop-shell performance baseline.
#
# Samples the RUNNING shell (no restart by default) and prints one JSON
# report to stdout: host metadata plus steady-state memory, IPC latency,
# and layer counts. Numbers are point-in-time observations for
# regression comparison, never published estimates — see
# docs/PERF_BASELINE.md. Reports are not committed to the repo.
#
# Usage: ./scripts/perf-baseline.sh [--samples N] [--interval S]
#                                     [--restart] [--out FILE]
#   --restart  restart the shell first and measure time-to-IPC-ready
#              (disruptive: the desktop reloads; default off).
set -euo pipefail

SAMPLES=5
INTERVAL=2
RESTART=0
OUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        --samples) SAMPLES="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --restart) RESTART=1; shift ;;
        --out) OUT="$2"; shift 2 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
done

# The shell runs as `quickshell` (distro binary) or `qs` (wrapper entry
# point, e.g. the QA guest): prefer an exact quickshell match, else the
# oldest qs — the daemon, not a transient `qs ipc` client.
shell_pid() {
    PID="$(pgrep -x quickshell | head -1)"
    if [ -z "${PID}" ]; then PID="$(pgrep -x -o qs)"; fi
    printf '%s' "${PID}"
}

PID="$(shell_pid)"
if [ -z "${PID}" ]; then
    echo "no running quickshell instance" >&2
    exit 1
fi

START_READY_MS=""
if [ "${RESTART}" -eq 1 ]; then
    T0=$(date +%s%3N)
    horneroctl shell restart --yes >/dev/null
    for _ in $(seq 1 60); do
        if qs ipc call lock isLocked >/dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    T1=$(date +%s%3N)
    START_READY_MS=$((T1 - T0))
    PID="$(shell_pid)"
fi

QS_VERSION="$(quickshell --version 2>/dev/null || qs --version 2>/dev/null || true)"
QS_VERSION="$(printf '%s' "${QS_VERSION}" | head -1)"
CORES="$(nproc)"
MEM_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
MONITORS="$(hyprctl monitors 2>/dev/null | grep -c '^Monitor' || true)"
QML_FILES="$(find ~/.config/quickshell -name '*.qml' 2>/dev/null | wc -l)"

SAMPLE_JSON=""
for _ in $(seq 1 "${SAMPLES}"); do
    RSS_KB="$(ps -o rss= -p "${PID}" | tr -d ' ')"
    PSS_KB="$(awk '/^Pss:/ {s+=$2} END {print s+0}' "/proc/${PID}/smaps_rollup" 2>/dev/null || true)"
    L0=$(date +%s%3N)
    qs ipc call lock isLocked >/dev/null 2>&1
    L1=$(date +%s%3N)
    LAYERS="$(hyprctl layers 2>/dev/null | grep -c 'namespace:' || true)"
    SAMPLE_JSON="${SAMPLE_JSON}{\"rss_kb\": ${RSS_KB}, \"pss_kb\": ${PSS_KB}, \"ipc_ms\": $((L1 - L0)), \"layers\": ${LAYERS}},"
    sleep "${INTERVAL}"
done
SAMPLE_JSON="[${SAMPLE_JSON%,}]"

export HB_QS_VERSION="${QS_VERSION}" HB_CORES="${CORES}" HB_MEM_KB="${MEM_KB}" \
    HB_MONITORS="${MONITORS}" HB_QML_FILES="${QML_FILES}" HB_PID="${PID}" \
    HB_START_MS="${START_READY_MS}" HB_SAMPLES="${SAMPLE_JSON}" HB_OUT="${OUT}"
REPORT="$(python3 - <<'EOF'
import json, os
from datetime import datetime, timezone
print(json.dumps({
    "ts_utc": datetime.now(timezone.utc).isoformat(),
    "quickshell": os.environ["HB_QS_VERSION"],
    "cores": int(os.environ["HB_CORES"]),
    "mem_total_kb": int(os.environ["HB_MEM_KB"]),
    "monitors": int(os.environ["HB_MONITORS"]),
    "qml_files_live": int(os.environ["HB_QML_FILES"]),
    "shell_pid": int(os.environ["HB_PID"]),
    "startup_ready_ms": os.environ["HB_START_MS"],
    "samples": json.loads(os.environ["HB_SAMPLES"]),
}, indent=2))
EOF
)"
if [ -n "${OUT}" ]; then
    printf '%s\n' "${REPORT}" > "${OUT}"
else
    printf '%s\n' "${REPORT}"
fi
