# Colour scheme store — Hornero Signal

Question: where does the shell get its colours, and who writes them?

## Decision: one live scheme file, complete role tables, one optional synthesiser

The shell reads a single schema-v2 file,
`${XDG_STATE_HOME:-~/.local/state}/hornero/signal/scheme.json`, through a
`FileView` watcher in `services/Signal.qml`. Every theme — built-in or from
the catalogue — is a complete table of Signal roles (RFC 0001 §3.1). The only
palette generator is the optional Hornero Chromatic engine
([RFC 0002](https://github.com/HorneroOS/docs/blob/main/development/rfc-0002-hornero-chromatic.md), not implemented yet), which produces the same complete
table; the file format and the watcher do not change.

Writers:

- `horneroctl appearance theme apply <id>` for catalogue themes (owned by
  `HorneroOS/hornero`, themes owned by `HorneroOS/config`).
- horneroctl for the reserved `hornero-chromatic` theme (RFC 0002): it runs
  the native `hornero-chromatic` helper, validates the result against
  config's gate table and writes the scheme like any other theme. The shell
  never writes a Chromatic scheme; its previews stay in memory.
- The shell for its three built-ins (`hornero-signal-night`,
  `hornero-signal-day`, `hornero-signal-contrast`), atomically (temporary
  file + `mv`), and on first run when the file is missing.

## Why

1. **Design-owned colours.** Hornero Signal roles are art-directed and
   contrast-tested (`tests/test_contrast_aa.py`). Chromatic keeps the Signal
   lightness ladder, takes only hue and chroma from the image and solves
   contrast by construction; horneroctl re-validates before writing, so a
   generated palette that would fail AA is never applied.
2. **One format for every consumer.** The same role names feed GTK, Qt,
   terminals, Hyprland, hyprlock, the greeter and the website generators
   (`HorneroOS/config` `profiles/themes/tokens.schema.json`).
3. **No external dependency.** The Material-era Python colour library is
   gone; Chromatic is native C++ on Qt, with `ffmpeg` optional for video.
4. **The shell stays coherent without the CLI.** Built-in tables are
   compiled into `Signal.qml`, so a missing or invalid scheme file still
   renders the configured built-in.

## Non-goals

- Wallpapers recolour the UI only when the user selects Chromatic.
- No Material scheme types or roles; Chromatic variants are Signal parameter
  sets (RFC 0002 §6).
- No compatibility layer for Material 3 role names or schema-1 files: an old
  `smart-colors/scheme.json` is simply ignored.
