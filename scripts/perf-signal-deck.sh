#!/usr/bin/env bash
# Idle-CPU comparison of the experience modes, with focus on the Signal
# instrument deck (docs/EXPERIENCE.md "Idle-CPU measurement").
#
# Switches the RUNNING shell between modes through its own IPC and samples
# each with scripts/perf-baseline.sh, then prints one table: median shell
# CPU %, median RSS, desktop-widget layers per mode. It is meant for the
# disposable QA guest (docs/VM_TESTING.md). It changes the active experience
# mode and restores the original one on exit, but it still touches a live
# session, so it refuses to run unless HORNERO_DISPOSABLE_SESSION=1 is set.
#
# Usage: HORNERO_DISPOSABLE_SESSION=1 ./scripts/perf-signal-deck.sh
#          [--samples N] [--interval S] [--settle S] [--modes a,b,c] [--out FILE]
#          [--max-cpu PCT]
#
# --max-cpu PCT is the idle budget (shell#651): the run exits 1 when any
# measured mode's median CPU exceeds PCT percent of one core. Run it on an
# empty workspace with no popouts; windows that cover the desktop make a
# mode look cheaper than it is.
set -euo pipefail

SAMPLES=6
INTERVAL=2
SETTLE=8
MODES="everyday,signal,gaming"
OUT=""
MAX_CPU=""
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

while [ $# -gt 0 ]; do
    case "$1" in
        --samples) SAMPLES="$2"; shift 2 ;;
        --interval) INTERVAL="$2"; shift 2 ;;
        --settle) SETTLE="$2"; shift 2 ;;
        --modes) MODES="$2"; shift 2 ;;
        --out) OUT="$2"; shift 2 ;;
        --max-cpu) MAX_CPU="$2"; shift 2 ;;
        *) echo "unknown flag: $1" >&2; exit 2 ;;
    esac
done

if [ "${HORNERO_DISPOSABLE_SESSION:-}" != "1" ]; then
    echo "refusing to switch experience modes: set HORNERO_DISPOSABLE_SESSION=1 in a disposable (QA guest) session" >&2
    exit 3
fi
for tool in qs python3; do
    command -v "${tool}" >/dev/null || { echo "missing ${tool}" >&2; exit 1; }
done

ORIGINAL="$(qs ipc call experience get | tr -d '[:space:]')"
restore() { qs ipc call experience set "${ORIGINAL}" >/dev/null 2>&1 || true; }
trap restore EXIT

TMP="$(mktemp -d "${XDG_RUNTIME_DIR:-${HOME}/.cache}/hornero-deck-perf.XXXXXX")"
trap 'restore; rm -rf "${TMP}"' EXIT

IFS=',' read -r -a LIST <<<"${MODES}"
for mode in "${LIST[@]}"; do
    reply="$(qs ipc call experience set "${mode}")"
    case "${reply}" in ok*) ;; *) echo "mode ${mode}: ${reply}" >&2; exit 1 ;; esac
    sleep "${SETTLE}"
    "${HERE}/perf-baseline.sh" --samples "${SAMPLES}" --interval "${INTERVAL}" --format json --out "${TMP}/${mode}.json" >/dev/null
done

REPORT="$(MODES="${MODES}" TMP="${TMP}" MAX_CPU="${MAX_CPU}" python3 - <<'PY'
import json, os, statistics
rows = []
for mode in os.environ["MODES"].split(","):
    data = json.load(open(os.path.join(os.environ["TMP"], mode + ".json")))
    s = data["samples"]
    cpu = [x["cpu_percent"] for x in s]
    rss = [x["rss_kb"] for x in s]
    layers = [x["layers"] for x in s if x.get("layers") is not None]
    rows.append((mode, statistics.median(cpu), max(cpu), statistics.median(rss) / 1024, statistics.median(layers) if layers else None))
print(f"{'mode':<10} {'cpu% med':>9} {'cpu% max':>9} {'rss MiB':>9} {'layers':>7}")
for mode, med, mx, rss, layers in rows:
    print(f"{mode:<10} {med:>9.2f} {mx:>9.2f} {rss:>9.1f} {('n/a' if layers is None else int(layers)):>7}")
budget = os.environ.get("MAX_CPU", "")
if budget:
    over = [(m, med) for m, med, *_ in rows if med > float(budget)]
    for m, med in over:
        print(f"OVER BUDGET: {m} median {med:.2f}% > {float(budget):g}%")
    print("budget " + ("FAILED" if over else "ok") + f" (median CPU <= {float(budget):g}% of one core)")
PY
)"
printf '%s\n' "${REPORT}"
if [ -n "${OUT}" ]; then printf '%s\n' "${REPORT}" >"${OUT}"; fi
case "${REPORT}" in *"budget FAILED"*) exit 1 ;; esac
