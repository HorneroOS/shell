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

## Hornero Chromatic

The native dynamic-colour engine (`libs/chromatic/`, RFC 0002 in
HorneroOS/docs) restores the wallpaper-colour capability Caelestia offered,
as a new C++ implementation that emits Hornero Signal roles directly.
Caelestia (shell and cli) is credited for the feature lineage — wallpaper
seeds, variants, the "hard" flavour (here `surfaceDepth: deep`), smart mode
and variant inference, app templates — and no Caelestia code or tables
were copied. Colour maths use OKLab/OKLCH by Björn Ottosson (2020, MIT) and
the WCAG 2.x contrast formula; see `NOTICE` and
[Chromatic engine](CHROMATIC-ENGINE.md).
