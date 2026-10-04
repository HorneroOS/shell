# Shell provenance

Hornero Shell began as a Quickshell extraction from
[ulises-jeremias/dotfiles](https://github.com/ulises-jeremias/dotfiles), pinned
at commit `b26db04`. The project then moved the runtime, presets, theme flow,
and package integration into their HorneroOS repositories. Current ownership
and interfaces are documented in [Architecture](ARCHITECTURE.md),
[IPC](IPC.md), and [Layouts](LAYOUTS.md).

The imported runtime derives from
[caelestia-dots/shell](https://github.com/caelestia-dots/shell) by
[soramane](https://github.com/soramane). Its upstream attribution and GPL-3.0
license are preserved in `NOTICE` and `LICENSE.GPL-3.0`. HorneroOS has since
changed the runtime, Control Center, bar topology, appearance pipeline, and
application contracts substantially; this history does not define the current
product interface.
