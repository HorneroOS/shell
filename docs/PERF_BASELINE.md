# Performance baseline

How to measure the Hornero shell repeatably so regressions show up as
numbers, not vibes. The harness samples the running shell; reports are
point-in-time observations, never published estimates. An anonymized,
dated reference capture lives in `docs/perf-baselines/` so reviewers can
see the shape of an observed run without mistaking it for a portable
guarantee.

## What is measured

- `startup_ready_ms` — restart to first answered IPC call (only with
  `--restart`; disruptive, the desktop reloads).
- `rss_kb` / `pss_kb` — quickshell resident/proportional memory per
  sample (`ps`, `/proc/<pid>/smaps_rollup`). `memory_breakdown` adds the
  kernel-reported `pss_anon_kb`, `pss_file_kb`, and `pss_shmem_kb` portions
  where available. Unsupported or unreadable fields are `null`, never
  treated as zero. These categories help distinguish private anonymous
  allocations from file-backed and shared mappings; they are diagnostic
  signals, not a memory-leak diagnosis.
- `cpu_percent` — process CPU time consumed between samples, calculated
  from `/proc/<pid>/stat` ticks over the measured wall interval. `cores`
  reports the effective CPUs visible to the harness (including cgroup
  limits); `host_cores` reports online host CPUs.
- `ipc_ms` — round trip of `qs ipc --pid <shell-pid> call lock isLocked` per sample.
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
a table with CPU%, RSS, PSS, its anonymous/file/shared breakdown, IPC latency,
and layer-surface counts. Use
`--format json` for structured output. The
`--restart` option is intentionally disruptive and must only be used from a
disposable test session or with the user's explicit approval. The harness
uses Quickshell's `--pid` selection for every IPC probe, so it always measures
the exact live process even when the caller's environment or working directory
differs. The helper clears mutually exclusive config selectors for those IPC
calls. Config selection is also recovered from the process environment or its
`--path` / `--config` / `--manifest` arguments. Relative `--path` values are
resolved against the process working directory when counting available QML
files, and directory paths count only files inside that selected config.

The script reports steady-state measurements from the currently running
shell. It does not measure the greeter-to-desktop path or the first rendered
frame. `startup_ready_ms` is only a restart-to-IPC-ready proxy and must not be
described as login-to-first-frame latency. A true first-frame measurement needs
a disposable graphical session and an external frame observer; IPC readiness
alone is insufficient evidence.

## How to compare

Run twice under the same conditions (same session age, same open
windows, same companion state) and diff the `samples` medians. A
regression is a sustained median move across runs, not one outlier
sample. Session age matters: compare fresh-start to fresh-start, or
steady-state to steady-state at similar uptimes.

## Reference captures and rules

- Raw reports are not committed: they contain machine/session details such as
  process IDs, host memory, CPU counts, uptime, and timestamps. A reviewed
  reference capture may be committed only after removing those details and
  documenting the software version, sampling method, and limitations.
- Reference captures are evidence from one environment and one time. They are
  not defaults, SLOs, release claims, or proof of a regression/improvement by
  themselves. Compare them only with runs made using the same method and
  materially similar shell/compositor conditions.
- Never publish estimates or projections — only observed runs with
  their metadata attached.
- Keep the harness dependency-free: POSIX shell + `python3` (already a
  test dependency) + the shell's own CLI surface.

## Current reference

See [`perf-baselines/2026-10-13.md`](perf-baselines/2026-10-13.md) for the
latest sanitized steady-state observation and
[`perf-baselines/2026-10-12.md`](perf-baselines/2026-10-12.md) for the earlier
capture. These intentionally do not claim a clean-login,
startup-to-first-frame, or per-surface frame-cost result. The observations
come from different Shell and Quickshell versions and must not be read as a
before/after comparison.
