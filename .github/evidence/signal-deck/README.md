# signal-deck — layout evidence (agent G, shell#478)

- `deck-layout.png` / `.svg` — a **layout diagram, not a render**: the
  output of `services/deck.js` `compose()` (the real solver, run under node)
  for five displays: 1920x1080 at 1x (also with the desktop clock reserved at
  bottom-right), 2560x1440 at 1.25x, 3840x2160 at 2x, 1366x768 and a
  3440x1440 ultrawide. Boxes are the real widget rectangles in logical
  pixels inside the widget area (bar edge of 40 px and the 48 px shell margin
  removed); dashed teal outline = the PluginKit desktop frame size.
- `layout_diagram.py <repo-root> <out-dir>` regenerates both files.
- Nothing here shows rendered widgets, glow or motion. Visual validation of
  the deck in the QA VM is still owed (the VM was held by another run).
