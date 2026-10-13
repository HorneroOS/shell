#!/usr/bin/env bash
# Repeatable desktop-shell performance baseline.
#
# Samples the RUNNING shell (no restart by default) and prints a human-readable
# table; --format json provides machine-readable output. It reports metadata
# plus steady-state CPU, memory, IPC latency, and compositor layer counts.
# Numbers are point-in-time observations for
# regression comparison, never published estimates — see
# docs/PERF_BASELINE.md. Reports are not committed to the repo.
#
# Usage: ./scripts/perf-baseline.sh [--samples N] [--interval S]
#                                     [--restart] [--format table|json] [--out FILE]
#   --restart  restart the shell first and measure time-to-IPC-ready
#              (disruptive: the desktop reloads; default off).
set -euo pipefail

SAMPLES=5
INTERVAL=2
RESTART=0
OUT=""
FORMAT="table"

while [ $# -gt 0 ]; do
    case "$1" in
        --samples) SAMPLES="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --restart) RESTART=1; shift ;;
        --out) OUT="$2"; shift 2 ;;
        --format) FORMAT="$2"; shift 2 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
done

if [ "${FORMAT}" != "table" ] && [ "${FORMAT}" != "json" ]; then
    echo "--format must be table or json" >&2
    exit 2
fi

# The shell runs as `quickshell` (distro binary) or `qs` (wrapper entry
# point, e.g. the QA guest): prefer an exact quickshell match, else the
# oldest qs — the daemon, not a transient `qs ipc` client.
shell_pid() {
    PID="$(pgrep -x quickshell 2>/dev/null || true)"
    PID="${PID%%$'\n'*}"
    if [ -z "${PID}" ]; then PID="$(pgrep -x -o qs 2>/dev/null || true)"; fi
    printf '%s' "${PID}"
}

PID="$(shell_pid)"
if [ -z "${PID}" ]; then
    echo "no running quickshell instance" >&2
    exit 1
fi

# A system-installed shell may run with a package-owned QS_CONFIG_PATH that
# is not present in the caller's environment. Reuse the live process's
# selection for accurate QML metadata; IPC itself targets the process by PID.
proc_env_value() {
    local key="$1" entry
    if [ ! -r "${HORNERO_PROC_ROOT:-/proc}/${PID}/environ" ]; then return 0; fi
    while IFS= read -r -d '' entry; do
        case "${entry}" in
            "${key}="*) printf '%s' "${entry#*=}"; return 0 ;;
        esac
    done < "${HORNERO_PROC_ROOT:-/proc}/${PID}/environ"
    return 0
}

# Quickshell launched with `--path` or `--config` does not have to export the
# matching QS_CONFIG_* variables. Recover those arguments from the live process
# before falling back to the caller's default config.
proc_cmdline_value() {
    local key="$1" long_flag short_flag arg index
    local -a args=()
    case "${key}" in
        QS_CONFIG_PATH) long_flag="--path"; short_flag="-p" ;;
        QS_CONFIG_NAME) long_flag="--config"; short_flag="-c" ;;
        QS_MANIFEST) long_flag="--manifest"; short_flag="-m" ;;
        *) return 0 ;;
    esac
    if [ ! -r "${HORNERO_PROC_ROOT:-/proc}/${PID}/cmdline" ]; then return 0; fi
    mapfile -d '' -t args < "${HORNERO_PROC_ROOT:-/proc}/${PID}/cmdline"
    for index in "${!args[@]}"; do
        arg="${args[${index}]}"
        case "${arg}" in
            "${long_flag}"|"${short_flag}")
                if (( index + 1 < ${#args[@]} )); then
                    printf '%s' "${args[$((index + 1))]}"
                    return 0
                fi
                ;;
            "${long_flag}="*)
                printf '%s' "${arg#*=}"
                return 0
                ;;
        esac
    done
    return 0
}

for key in QS_CONFIG_PATH QS_CONFIG_NAME QS_MANIFEST QS_PLUGIN_PATH NIRI_SOCKET HYPRLAND_INSTANCE_SIGNATURE; do
    value="$(proc_cmdline_value "${key}")"
    if [ -z "${value}" ]; then value="$(proc_env_value "${key}")"; fi
    if [ -z "${value}" ] && [[ -v "${key}" ]]; then
        value="${!key}"
    fi
    if [ -n "${value}" ]; then export "${key}=${value}"; fi
done

qs_ipc() {
    env -u QS_CONFIG_PATH -u QS_CONFIG_NAME -u QS_MANIFEST \
        qs ipc --pid "${PID}" "$@"
}

if ! qs_ipc call lock isLocked >/dev/null 2>&1; then
    echo "cannot reach the running Quickshell process by PID; verify it is alive and IPC is available" >&2
    exit 1
fi

detect_compositor() {
    if [ -n "${NIRI_SOCKET:-}" ] && command -v niri >/dev/null 2>&1; then
        printf 'niri'
    elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null 2>&1; then
        printf 'hyprland'
    elif command -v niri >/dev/null 2>&1 && timeout 2 niri msg --json outputs >/dev/null 2>&1; then
        printf 'niri'
    elif command -v hyprctl >/dev/null 2>&1 && timeout 2 hyprctl monitors >/dev/null 2>&1; then
        printf 'hyprland'
    else
        printf 'unknown'
    fi
}

COMPOSITOR="$(detect_compositor)"

# Return a count from Niri's stable JSON IPC. Niri currently prints the
# response payload directly; unwrap the Ok/Outputs/Layers forms as well so
# older CLI serialization remains usable. Disabled outputs have no mode and
# do not count as active monitors.
niri_json_count() {
    local kind="$1" payload="$2"
    HORNERO_NIRI_JSON="${payload}" python3 - "${kind}" <<'PY'
import json
import os
import sys

kind = sys.argv[1]
try:
    value = json.loads(os.environ["HORNERO_NIRI_JSON"])
except (KeyError, json.JSONDecodeError):
    print("null")
    raise SystemExit(0)

if isinstance(value, dict) and "Ok" in value:
    value = value["Ok"]
elif isinstance(value, dict) and "Err" in value:
    print("null")
    raise SystemExit(0)
key = "Outputs" if kind == "outputs" else "Layers"
if isinstance(value, dict) and key in value:
    value = value[key]

if kind == "outputs" and isinstance(value, dict):
    if any(
        not isinstance(output, dict) or "current_mode" not in output
        for output in value.values()
    ):
        print("null")
        raise SystemExit(0)
    count = sum(
        1 for output in value.values() if output["current_mode"] is not None
    )
elif kind == "layers" and isinstance(value, list):
    if any(not isinstance(layer, dict) or "namespace" not in layer for layer in value):
        print("null")
        raise SystemExit(0)
    count = len(value)
else:
    print("null")
    raise SystemExit(0)
print(count)
PY
}

compositor_count() {
    local kind="$1" output
    case "${COMPOSITOR}:${kind}" in
        hyprland:outputs)
            timeout 2 hyprctl monitors 2>/dev/null | grep -c '^Monitor' || true
            ;;
        hyprland:layers)
            timeout 2 hyprctl layers 2>/dev/null | grep -c 'namespace:' || true
            ;;
        niri:outputs)
            output="$(timeout 2 niri msg --json outputs 2>/dev/null || true)"
            niri_json_count outputs "${output}"
            ;;
        niri:layers)
            output="$(timeout 2 niri msg --json layers 2>/dev/null || true)"
            niri_json_count layers "${output}"
            ;;
        *) printf 'null' ;;
    esac
}

START_READY_MS=""
if [ "${RESTART}" -eq 1 ]; then
    T0=$(date +%s%3N)
    horneroctl shell restart --yes >/dev/null
    for _ in $(seq 1 60); do
        PID="$(shell_pid)"
        if [ -n "${PID}" ] && qs_ipc call lock isLocked >/dev/null 2>&1; then
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
HOST_CORES="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc --all 2>/dev/null || nproc)"
MEM_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
MONITORS="$(compositor_count outputs)"
if [ -n "${QS_CONFIG_PATH:-}" ]; then
    QML_CONFIG_PATH="${QS_CONFIG_PATH}"
    if [[ "${QML_CONFIG_PATH}" != /* ]]; then
        QML_CONFIG_PATH="${HORNERO_PROC_ROOT:-/proc}/${PID}/cwd/${QML_CONFIG_PATH}"
    fi
    if [ -d "${QML_CONFIG_PATH}" ]; then
        QML_ROOT="${QML_CONFIG_PATH}"
    else
        QML_ROOT="$(dirname "${QML_CONFIG_PATH}")"
    fi
else
    QML_ROOT="${XDG_CONFIG_HOME:-${HOME}/.config}/quickshell"
fi
QML_FILES_AVAILABLE="$(find "${QML_ROOT}" -name '*.qml' 2>/dev/null | wc -l)"
SHELL_UPTIME="$(ps -o etimes= -p "${PID}" 2>/dev/null | tr -d ' ' || true)"
CLK_TCK="$(getconf CLK_TCK 2>/dev/null || printf '100')"

cpu_ticks() {
    python3 - "${PID}" <<'PY'
import sys
from pathlib import Path

try:
    stat = Path(f"/proc/{sys.argv[1]}/stat").read_text()
    fields = stat[stat.rfind(")") + 2:].split()
    print(int(fields[11]) + int(fields[12]))
except (IndexError, OSError, ValueError):
    print(0)
PY
}

# smaps_rollup exposes the proportional set size split by backing type on
# current Linux kernels. Keep missing fields null so older kernels are not
# misreported as having zero anonymous/file/shared memory.
# HORNERO_PROC_ROOT is a test seam; live reports read from /proc by default.
memory_breakdown() {
    python3 - "${HORNERO_PROC_ROOT:-/proc}/${PID}/smaps_rollup" <<'PY'
import json
import re
import sys
from pathlib import Path

fields = {"Pss_Anon": "pss_anon_kb", "Pss_File": "pss_file_kb", "Pss_Shmem": "pss_shmem_kb"}
values = {name: None for name in fields.values()}
try:
    for line in Path(sys.argv[1]).read_text().splitlines():
        match = re.fullmatch(r"(Pss_Anon|Pss_File|Pss_Shmem):\s+(\d+) kB", line)
        if match:
            values[fields[match.group(1)]] = int(match.group(2))
except OSError:
    pass
print(json.dumps(values, separators=(",", ":")))
PY
}

SAMPLE_JSON=""
PREV_CPU_TICKS="$(cpu_ticks)"
PREV_CPU_TIME="$(date +%s%3N)"
for _ in $(seq 1 "${SAMPLES}"); do
    RSS_KB="$(ps -o rss= -p "${PID}" | tr -d ' ')"
    PSS_KB="$(awk '/^Pss:/ {s+=$2} END {print s+0}' "/proc/${PID}/smaps_rollup" 2>/dev/null || true)"
    MEMORY_BREAKDOWN="$(memory_breakdown)"
    L0=$(date +%s%3N)
    qs_ipc call lock isLocked >/dev/null 2>&1
    L1=$(date +%s%3N)
    LAYERS="$(compositor_count layers)"
    sleep "${INTERVAL}"
    NOW_CPU_TICKS="$(cpu_ticks)"
    NOW_CPU_TIME="$(date +%s%3N)"
    ELAPSED_MS=$((NOW_CPU_TIME - PREV_CPU_TIME))
    CPU_PERCENT="$(awk -v before="${PREV_CPU_TICKS}" -v after="${NOW_CPU_TICKS}" \
        -v elapsed="${ELAPSED_MS}" -v ticks="${CLK_TCK}" \
        'BEGIN { if (elapsed > 0 && ticks > 0) printf "%.2f", ((after - before) * 100000) / (ticks * elapsed); else print "0.00" }')"
    SAMPLE_JSON="${SAMPLE_JSON}{\"rss_kb\": ${RSS_KB:-0}, \"pss_kb\": ${PSS_KB:-0}, \"memory_breakdown\": ${MEMORY_BREAKDOWN}, \"cpu_percent\": ${CPU_PERCENT}, \"ipc_ms\": $((L1 - L0)), \"layers\": ${LAYERS}},"
    PREV_CPU_TICKS="${NOW_CPU_TICKS}"
    PREV_CPU_TIME="${NOW_CPU_TIME}"
done
SAMPLE_JSON="[${SAMPLE_JSON%,}]"

export HB_QS_VERSION="${QS_VERSION}" HB_CORES="${CORES}" \
    HB_HOST_CORES="${HOST_CORES}" HB_MEM_KB="${MEM_KB}" \
    HB_COMPOSITOR="${COMPOSITOR}" HB_MONITORS="${MONITORS}" \
    HB_QML_FILES_AVAILABLE="${QML_FILES_AVAILABLE}" HB_PID="${PID}" HB_SHELL_UPTIME="${SHELL_UPTIME}" \
    HB_START_MS="${START_READY_MS}" HB_SAMPLES="${SAMPLE_JSON}" HB_OUT="${OUT}"
REPORT="$(python3 - <<'EOF'
import json, os
from datetime import datetime, timezone
print(json.dumps({
    "ts_utc": datetime.now(timezone.utc).isoformat(),
    "quickshell": os.environ["HB_QS_VERSION"],
    "compositor": os.environ["HB_COMPOSITOR"],
    "cores": int(os.environ["HB_CORES"]),
    "host_cores": int(os.environ["HB_HOST_CORES"]),
    "mem_total_kb": int(os.environ["HB_MEM_KB"]),
    "monitors": int(os.environ["HB_MONITORS"]) if os.environ["HB_MONITORS"].isdigit() else None,
    "qml_files_available": int(os.environ["HB_QML_FILES_AVAILABLE"]),
    "shell_pid": int(os.environ["HB_PID"]),
    "shell_uptime_sec": int(os.environ["HB_SHELL_UPTIME"]) if os.environ["HB_SHELL_UPTIME"].isdigit() else None,
    "startup_ready_ms": os.environ["HB_START_MS"],
    "samples": json.loads(os.environ["HB_SAMPLES"]),
}, indent=2))
EOF
)"
if [ "${FORMAT}" = "json" ]; then
    OUTPUT="${REPORT}"
else
    OUTPUT="$(python3 - "${REPORT}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
print(f"Hornero Shell performance sample ({data['ts_utc']})")
print(
    f"Compositor: {data['compositor']} | Quickshell: {data['quickshell']} | "
    f"monitors: {data['monitors'] if data['monitors'] is not None else 'n/a'} | "
    f"QML files available: {data['qml_files_available']} | shell age: "
    f"{data['shell_uptime_sec'] if data['shell_uptime_sec'] is not None else 'n/a'}s"
)
print(f"CPU cores: {data['cores']} effective / {data['host_cores']} online | RAM: {data['mem_total_kb'] / 1048576:.1f} GiB")
if data["startup_ready_ms"]:
    print(f"Restart to IPC-ready: {data['startup_ready_ms']} ms")
print("Sample  RSS MiB  PSS MiB  Anon MiB  File MiB  Shared MiB  CPU %  IPC ms  Layers")
for index, sample in enumerate(data["samples"], start=1):
    layers = sample["layers"] if sample["layers"] is not None else "n/a"
    memory = sample["memory_breakdown"]
    def mib(value):
        return f"{value / 1024:>8.1f}" if value is not None else f"{'n/a':>8}"
    print(
        f"{index:>6}  {sample['rss_kb'] / 1024:>7.1f}  "
        f"{sample['pss_kb'] / 1024:>7.1f}  {mib(memory['pss_anon_kb'])}  "
        f"{mib(memory['pss_file_kb'])}  {mib(memory['pss_shmem_kb'])}  "
        f"{sample['cpu_percent']:>5.2f}  "
        f"{sample['ipc_ms']:>6}  {layers:>6}"
    )
PY
)"
fi
if [ -n "${OUT}" ]; then
    printf '%s\n' "${OUTPUT}" > "${OUT}"
else
    printf '%s\n' "${OUTPUT}"
fi
