# Theme readiness graphical evidence

These frames come from Hornero QA native QEMU runs at 1280×800. Input was delivered through the scenario pointer and keyboard lanes.

- `before-split-state.png`: shell commit `61a4580`; selecting a recipe with missing external GTK styling left the shell in Light mode while GTK remained Hornero Dark.
- `after-dependency-state.png`: shell commit `e07a1ae`; the same unavailable external style is identified before apply, Hornero Dark remains current, and the preview explicitly says the current wallpaper is reused when no bundled wallpapers exist.

Each PNG has its unmodified Hornero QA screenshot sidecar beside it with run ID, SHA-256, product commits and environment.
