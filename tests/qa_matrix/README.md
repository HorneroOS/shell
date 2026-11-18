# Layout and scale QA matrix (offscreen)

Renders every layout preset (`presets/*.json`) with the real `Bar.qml` in an
offscreen Quickshell, per experience mode and viewport, and reports geometry
issues (overlapping entries, entries outside the screen, items wider than
their slot) as a `QAM {...}` JSON log line.

```sh
tests/qa_matrix/build.sh <worktree> <tree>
MODE=signal tests/qa_matrix/render.sh <tree> <tree>/presets/cockpit.json - - 1920 1080 1.25 out.png
```

`render.sh` isolates XDG and HOME under `$QAM_SCRATCH`. Offscreen limits:
layer effects (glow halo, Colouriser) are stubbed, there is one screen
(mixed-scale is rendered as separate runs), and popups are covered by the
solver sweep in `tests/placement/matrix.test.mjs`, not here.
