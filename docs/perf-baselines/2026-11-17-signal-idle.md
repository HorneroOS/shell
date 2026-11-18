# Signal-mode idle cost (shell#651) - 2026-11-17

Point-in-time observations from one host (Ryzen 9 5900X, Hyprland 0.57.2,
Quickshell 0.3.2, 1920x1080), isolated XDG state, Cockpit layout, Signal
mode, empty workspace, no popouts. Method: per-thread utime+stime from
`/proc/<pid>/task/*/stat` over 30-60 s. Not a guarantee or target.

## Bisect on the unfixed shell (Signal, deck on, 30 s windows, % of one core)

| Variation (via `experience customise signal`) | Total | Main thread |
|---|---|---|
| defaults (2 Hz telemetry) | 8.5 | 5.3 |
| telemetry 0.1 Hz | 4.1 | 2.1 |
| telemetry 1 Hz | 4.9 | 2.5 |
| telemetry 4 Hz | 14.6 | 9.4 |
| deck off | 7.7 | 4.8 |
| glow off | 5.7 | 3.3 |
| scanlines off / chrome off / motion off | 9.0 / 8.1 / 8.3 | 5.5 / 5.0 / 5.0 |
| deck, glow, scanlines, chrome all off | 7.4 | 4.8 |

Main-thread cost follows the telemetry rate (about 2.2 points per Hz); the
visual layers are secondary. Each tick spawned `sensors`, a GPU read and
`lsblk`.

## Limits

- The 42% in the issue was not reproduced; the unfixed shell measured
  3.7-8.5% here. Conditions that produced 42% (concurrent pytest, session
  state, lock state) are unknown.
- The deck extension bodies did not render in the later runs (empty
  frames), so before/after of the full deck is not claimed.
