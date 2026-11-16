# Colour scheme store — Hornero Signal

Question: where does the shell get its colours, and who writes them?

## Decision: one live scheme file, complete role tables, no synthesis

The shell reads a single schema-v2 file,
`${XDG_STATE_HOME:-~/.local/state}/hornero/signal/scheme.json`, through a
`FileView` watcher in `services/Signal.qml`. Every theme — built-in or from
the catalogue — is a complete table of Signal roles (RFC 0001 §3.1). There is
no palette generation in the shell or behind it.

Writers:

- `horneroctl appearance theme apply <id>` for catalogue themes (owned by
  `HorneroOS/hornero`, themes owned by `HorneroOS/config`).
- The shell for its three built-ins (`hornero-signal-night`,
  `hornero-signal-day`, `hornero-signal-contrast`), atomically (temporary
  file + `mv`), and on first run when the file is missing.

## Why

1. **Design-owned colours.** Hornero Signal roles are art-directed and
   contrast-tested (`tests/test_contrast_aa.py`); a wallpaper-derived palette
   cannot guarantee AA on every surface.
2. **One format for every consumer.** The same role names feed GTK, Qt,
   terminals, Hyprland, hyprlock, the greeter and the website generators
   (`HorneroOS/config` `profiles/themes/tokens.schema.json`).
3. **No external dependency.** Removing wallpaper synthesis removes the
   Python colour library and the CLI round-trip from the appearance path.
4. **The shell stays coherent without the CLI.** Built-in tables are
   compiled into `Signal.qml`, so a missing or invalid scheme file still
   renders the configured built-in.

## Non-goals

- Wallpapers never recolour the UI.
- No variants, flavours or scheme types.
- No compatibility layer for Material 3 role names or schema-1 files: an old
  `smart-colors/scheme.json` is simply ignored.
