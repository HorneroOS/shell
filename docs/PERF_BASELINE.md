# Performance baseline

How to measure the Hornero shell repeatably so regressions show up as
numbers, not vibes. The harness samples the running shell; reports are
point-in-time observations, never published estimates.

## What is measured

- `startup_ready_ms` — restart to first answered IPC call (only with
  `--restart`; disruptive, the desktop reloads).
- `rss_kb` / `pss_kb` — quickshell resident/proportional memory per
  sample (`ps`, `/proc/<pid>/smaps_rollup`).
- `ipc_ms` — round trip of `qs ipc call lock isLocked` per sample.
- `layers` — compositor layer-surface count per sample.
- Metadata: UTC timestamp, quickshell version, cores, RAM, monitor
  count, live QML file count, shell PID.

## How to run

```bash
./scripts/perf-baseline.sh                          # steady state, default 5x2s
./scripts/perf-baseline.sh --samples 3 --interval 1 # quick check
./scripts/perf-baseline.sh --restart                 # includes startup timing
./scripts/perf-baseline.sh --out /tmp/baseline.json  # save instead of print
```

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
