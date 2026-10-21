# Cold-start probe — plugin host + dashboard surface (2026-10-21)

Scope, stated narrowly: process wall time from `qs` launch to exit
for the isolated harness in `tests/perf/coldstart-harness.qml`
(checkout shell at `e0cefdf`), which loads the plugin host and the
dashboard plugin cards, prints `Plugins.status()` after a 100 ms
timer, and quits. This is **not** full-shell cold start (no bar, no
lock, no Control Center) and not a frame-cost measurement; both
remain owed for shell#47/#228.

Method: 5 sequential runs on the development host (Quickshell
0.3.2, 24 cores, 15 GiB RAM, live Hyprland session), wall time via
`date +%s%3N` around each run.

| Run | Wall time |
| --- | --- |
| 1 (cold caches) | 1993 ms |
| 2 | 517 ms |
| 3 | 620 ms |
| 4 | 568 ms |
| 5 | 612 ms |

Median of the warm runs (2–5): **612 ms**, including the harness's
own 100 ms status timer and process teardown. Each run reported
`loaded: 2` (the two enabled dashboard plugins; bar-placed plugins
stay `pending` in this harness because it has no bar surface).

Reading this honestly: the first-run penalty (~3.2× the warm
median) is page-cache/toolchain warm-up on a busy development
machine, not a product claim. Steady-state numbers live in
`docs/perf-baselines/2026-10-21.md`; the release performance gate
stays FAIL until full-shell cold start and per-surface frame cost
are measured in the disposable QA harness.

## Full-shell cold start (same host, later that day)

`tests/perf/run-fullshell-coldstart.sh` launches the real
checkout shell as a second instance and times from process start
until the bar's `Volume controls` accessible appears in the
AT-SPI tree — first interactive surface, not first frame. Three
runs: 1703, 1652 and 1666 ms (**median 1666 ms**). Error bound:
the probe walk itself takes ~95 ms and polling granularity is
200 ms, so read this as ≈1.7 s ± 0.3 s on this busy development
host (checkout at `a019968`). At that point per-surface frame
cost was still unmeasured; the performance gate stays FAIL and
no performance claim is made from these numbers.

## Launcher frame cost (same host, later that day)

`tests/perf/run-framecost.sh` renders the real launcher chain in
a full-screen window and counts `FrameAnimation` ticks over the
first 2 s of the open animation: **120 frames in 2.000 s
(16.67 ms average)** — exactly the 60 Hz vsync interval of this
display, with no dropped frame observed during the animation.
This bounds frame cost at ≤ one refresh interval on this host;
it does not isolate GPU or CPU cost per frame, and other
surfaces (dashboard, Control Center, lock) are unmeasured. The
performance gate stays FAIL.
