# Layout calibration evidence

Before (shell main at f47f323, shell#520 thin bars) and after (this change) strips for
each layout. Each image stacks the top and bottom 70 px of the screen (horizontal
bars) or the 130 px rail (vertical bars). File names are `<preset>-<logical height>.png`:
`1080` is 1920x1080, `768` is 1366x768, `720` is 1280x720 (the logical size of
1920x1080 at scale 1.5, where the density factor sees 720 px).

Provenance: offscreen render of `modules/bar/Bar.qml` through the Quickshell harness
(`QT_QPA_PLATFORM=offscreen`, isolated XDG dirs, synthetic gradient wallpaper, no private
data). The harness has no OS logo, weather, tray items or real window titles, and
paints the Hornero Left/Right frame as a flat `base` rectangle. This is not a VM or
real-host capture; layer-shell placement and popout anchoring are covered by the unit
tests and still need a VM pass.
