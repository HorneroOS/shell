# Layout Picker mixed-label baseline

This is the 1280×800 Niri VM capture that exposed the compact-card truncation. The Horizon subtitle ends in `partl…` at the right edge of its card. The capture shows the state before the label was shortened; it is not presented as an after screenshot.

The source capture was `/var/tmp/hornero-niri-run/niri-layout-picker.png`, captured 2026-10-04. The one-line fix changes only the mixed-backdrop suffix from ` · partly clear` to ` · mixed`; all-clear and opaque layouts retain their existing labels.
