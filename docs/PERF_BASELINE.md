# Performance baseline

How to measure the Hornero shell repeatably so regressions show up as
numbers, not vibes. The harness samples the running shell; reports are
point-in-time observations, never published estimates.

## What is measured

- `startup_ready_ms` — restart to first answered IPC call (only with
  `--restart`; disruptive, the desktop reloads).
- `rss_kb` / `pss_kb` — quickshell resident/proportional memory per
  sample (`ps`, `/proc/<pid>/smaps_rollup`).
- `cpu_percent` — process CPU time consumed between samples, calculated
  from `/proc/<pid>/stat` ticks over the measured wall interval. `cores`
  reports the effective CPUs visible to the harness (including cgroup
  limits); `host_cores` reports online host CPUs.
- `ipc_ms` — round trip of `qs ipc call lock isLocked` per sample.
- `layers` — compositor layer-surface count per sample.
- Metadata: UTC timestamp, quickshell version, cores, RAM, monitor
  count, compositor identity, number of QML files available in the selected
  config tree, shell PID and session age. The file count does not claim those
  files are loaded in memory. Monitor and layer counts use Hyprland IPC or
  Niri's JSON IPC; unsupported compositor metrics are `null`, not a
  misleading zero.

## How to run

```bash
./scripts/perf-baseline.sh                          # steady state, default 5x2s
./scripts/perf-baseline.sh --samples 3 --interval 1 # quick check
./scripts/perf-baseline.sh --restart                 # includes startup timing
./scripts/perf-baseline.sh --format json --out /tmp/baseline.json
```

The default run does not restart or otherwise mutate the desktop. It prints
a table with CPU%, RSS, PSS, IPC latency, and layer-surface counts. Use
`--format json` for structured output. The
`--restart` option is intentionally disruptive and must only be used from a
disposable test session or with the user's explicit approval. The harness
reuses the `QS_CONFIG_PATH`, `QS_CONFIG_NAME`, and compositor socket/signature
from the live Quickshell process when the caller does not already have them.

## How to compare

Run twice under the same conditions (same session age, same open
windows, same companion state) and diff the `samples` medians. A
regression is a sustained median move across runs, not one outlier
sample. Session age matters: compare fresh-start to fresh-start, or
steady-state to steady-state at similar uptimes.

## Rules

- Reports are never committed to the repo (machine-specific, rots fast).
- Never publish estimates or projections — only observed runs with
  their metadata attached.
- Keep the harness dependency-free: POSIX shell + `python3` (already a
  test dependency) + the shell's own CLI surface.
