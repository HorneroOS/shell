# Chromatic engine

Hornero Chromatic derives a complete Hornero Signal palette from a
wallpaper, an image, one or two seed colours, or the Signal house hues.
Design authority: RFC 0002 in HorneroOS/docs
(`development/rfc-0002-hornero-chromatic.md`). This page documents the
engine as built in this repository: the C++ library, the `hornero-chromatic`
helper used by horneroctl, and the `Hornero.Chromatic` QML module used for
in-process previews.

The engine only computes. It never writes the live scheme, `shell.json` or
any state; horneroctl applies (RFC 0002 §9). Its only writes are its own
disposable cache.

## Layout

| Path | What |
| --- | --- |
| `libs/chromatic/` | Static library, C++20, Qt6 Core + Gui only (`hornero_chromatic`) |
| `libs/chromatic/data/contrast-gates.json` | Gate table vendored byte-for-byte from HorneroOS/config; `contrast-gates.sha` pins the config commit |
| `extras/chromatic/main.cpp` | `hornero-chromatic`, installed to `/usr/lib/hornero/hornero-chromatic` |
| `extras/chromatic/bench.cpp` | `chromatic-bench` (not installed): timings and a seed sweep |
| `plugin/src/Hornero/Chromatic/` | QML module `Hornero.Chromatic` (CMake target `hornero-chromatic-qml`) |
| `tests/chromatic/` | Corpus generator, QtTest suite (`ctest -R chromatic`), goldens, manifest |
| `tests/test_chromatic_*.py` | Helper contract, goldens, properties, fuzz, perf, gate sync |

## Pipeline

1. **Source identity** — `sourceKey()` hashes the file (SHA-256; files over
   64 MiB: size plus first and last 4 MiB). The key is
   `sha256(contentDigest:algorithm)`. Path, size and mtime are never trusted.
2. **Decode** — `QImageReader` with content-based format detection and
   EXIF orientation; refuses more than 100 megapixels; JPEG uses scaled
   decoding. Embedded colour profiles (Display P3, Adobe RGB, CMYK) convert
   to sRGB. Animated GIF/WebP/APNG sample `n = min(8, frames)` frames at
   `floor(i·frames/n)`; a frame that fails fails the source. Video
   (`.mp4 .mkv .webm .mov .avi`) uses one `ffmpeg` frame at 1 s (or 0 s),
   cached under `frames/`; without `ffmpeg` the source is unreadable.
3. **Working image** — linear-light box filter to a longest side of 256 px;
   pixels with alpha below 0.5 are ignored.
4. **Statistics** — band-weighted (top and bottom 8 % count twice) OKLab
   lightness mean, extremes, percentiles and deviation; chroma mean,
   C90, C95; C95 of pixels lighter than 0.6 (neon test); 36-bin hue
   entropy; mean absolute Laplacian ("detail"); top and bottom band
   statistics; a 96 × 54 luminance grid (mean, deviation as bytes).
5. **Quantiser** — 5-bit sRGB histogram, median cut in OKLab to 16 boxes,
   8 Lloyd iterations, merge below ΔEOK 0.02. Deterministic, no randomness.
6. **Seeds** — RFC §4.4 score; up to five ranked seeds. A saturated object
   with at least 0.2 % share still seeds a grey image (see Deviations).
7. **Inference** — mode (0.58 / 0.68 thresholds, hysteresis from
   `currentMode`, the bar bands decide when they disagree by more than
   0.25), variant (C90 table), contrast (`auto` → `boosted` when detail
   exceeds 0.08), neon suggestion, personality, chroma class, temperature.
   Every decision lists its reason and can be overridden by the request.
8. **Synthesis** — the RFC §4.5 lightness ladder, variant parameters (§6),
   surface depth, chroma scale and hue shift; status anchors 29° / 150°
   harmonised toward the seed; cue candidates; wells, on-fills, inverse,
   glow (dark only, never monochrome or high contrast).
9. **Contrast solver** — surfaces never move; foregrounds move only in
   lightness (30-step bisection) to the level's minimum plus the 0.15
   margin, in a fixed order. Focus reaches its minimum on every surface;
   `inkFaint` gets a 3:1 decorative floor.
10. **Separation** — `signal`/`alert`, `cue`/`phosphor` and `signal`/`cue`
    must meet config's `chromaticExtra.separation` (ΔEOK ≥ 0.10 **and**
    hue ≥ 25°). The accents rotate away first; when hue alone cannot get
    there (low chroma), a deterministic search over accent hue, accent and
    anchor lightness and, last, a little extra accent chroma closes the gap.
    Status hues never move.
11. **Terminal** — ANSI 16 per RFC §4.8, normals 4.5:1 and brights 3:1 on
    `base`, visible normal → bright step.
12. **Over the wallpaper** — `minSurfaceAlpha` per translucent surface
    (smallest opacity in 0.50–1.00 at which `ink` and `inkMuted` keep their
    gate over the wallpaper's darkest and lightest greys; 1.0 without a
    wallpaper and for `high-contrast`), and `clearInk` for both polarities
    (each foreground solved to 4.5:1 against its own halo).
13. **Validation** — every generated scheme is validated against the gate
    table at its resolved level plus `chromaticExtra`. A failure is an
    engine bug: exit 4, nothing is emitted for apply.

## Helper: `hornero-chromatic`

```text
hornero-chromatic analyze  --source PATH [--frames N] [--cache-dir DIR | --no-cache] [--pretty]
hornero-chromatic generate (--source PATH | --seed HEX [--seed HEX] | --house) [--wallpaper PATH]
                           [--variant auto|balanced|vibrant|expressive|faithful|muted|monochrome|high-contrast|neon]
                           [--mode auto|dark|light] [--current-mode dark|light]
                           [--contrast auto|standard|boosted|maximum] [--depth standard|deep]
                           [--chroma 0.5..1.5] [--hue-shift -180..180] [--request FILE]
                           [--cache-dir DIR | --no-cache] [--pretty]
hornero-chromatic validate --scheme FILE [--level standard|boosted|maximum] [--pretty]
hornero-chromatic variants [--pretty]
hornero-chromatic version  [--pretty]
```

One JSON document on stdout (compact unless `--pretty`), diagnostics on
stderr. Exit codes: `0` ok, `2` usage, `3` source unreadable or
unsupported (including video without `ffmpeg`), `4` gates unreachable
(engine bug), `5` internal. Errors print
`{"schemaVersion":1,"engine":{…},"error":{"code":"usage|source-unreadable|gates-unreachable|internal","message":"…"}}`.

- `--request FILE` reads RFC §8.3 keys (`source`, `path`, `seeds`,
  `variant`, `mode`, `contrast`, `surfaceDepth`, `chroma`, `hueShift`,
  `currentMode`); unknown keys such as `follow` are ignored; flags override.
  `source` may also be `image:/abs/path`.
- `generate` output keys: `schemaVersion`, `engine`, `request`,
  `analysis` (`null` for seeds), `inference`, `scheme`, `gates`
  (`{level, passed, rows: [[label, value, min], …]}`), `adjustments`
  (`[{role, from, to, reason}]`), `fingerprint`.
- `scheme` is the RFC §8.1 live-scheme document: `schemaVersion: 2`,
  `id: "hornero-chromatic"`, `mode`, `palette`, `terminal`, `chromatic`
  (`version`, `engine`, `algorithm`, `fingerprint`, `request` without the
  path, `resolved`, `seeds`, `sourceKey`), `minSurfaceAlpha`, `clearInk`.
  It passes config's `signal_theme.validate_scheme` at its resolved level.
- `fingerprint` is `sha256:` over the compact, key-sorted `scheme` object
  without `chromatic.fingerprint`. Treat it as opaque: compare it, do not
  recompute it.
- `validate` returns `{schemaVersion, level, chromaticExtra, passed, rows}`
  and exits 0 even when `passed` is false; malformed input exits 2. A
  document with a `chromatic` block gets the extra rows.
- `version` returns `{schemaVersion, engine, algorithm, qt, formats, ffmpeg}`.

Cache: `--cache-dir` (default `$XDG_CACHE_HOME/hornero/chromatic`) holds
`analysis/<key>.json` (self-verifying; corrupt or stale entries are deleted
and recomputed) and `frames/<key>.png`; 64 MB cap, LRU by mtime.
`--no-cache` gives byte-identical output.

## QML: `Hornero.Chromatic`

```qml
import Hornero.Chromatic

ChromaticEngine.available        // true when the module loads
ChromaticEngine.engineVersion    // "1.0.0+a1"
ChromaticEngine.algorithm        // 1
ChromaticEngine.cacheDir         // read/write, default $XDG_CACHE_HOME/hornero/chromatic
ChromaticEngine.analyse(path): ChromaticJob
ChromaticEngine.generate(request): ChromaticJob   // JS object (keys above) or ChromaticRequest
ChromaticEngine.contrast(a, b): real
ChromaticEngine.ensureContrast(fg, bg, min): color   // lightness-only move
ChromaticEngine.mix(a, b, t): color                  // OKLab interpolation (palette tweens)
ChromaticEngine.variants(): [{id, label, description, darkOnly}]
ChromaticEngine.request(): ChromaticRequest          // default value object

job.running
job.cancel()                     // a cancelled job never emits
job.finished(result)             // result = the helper's generate/analyze JSON as a JS object
job.failed(code, message)        // "usage" | "source-unreadable" | "gates-unreachable" | "internal"
```

Work runs on a two-thread pool; at most one `generate` is in flight (a new
one cancels the previous); analyses are cached in memory (LRU of 8) and on
disk, so slider changes re-synthesise in well under a millisecond. Jobs are
owned by the engine and deleted after they finish, fail or are cancelled.
Previews and applies use the same library build, so the `fingerprint` of a
preview equals the applied one for the same request and file.

## C++ API

Namespace `hornero::chromatic`, headers in
`libs/chromatic/include/hornero/chromatic/`: `colour.hpp` (OKLab/OKLCH,
gamut mapping, WCAG, ΔE76, ΔEOK, hex), `source.hpp` (`sourceKey`,
`decode`), `analysis.hpp` (`analyse`), `request.hpp` (`Request`, enums,
`requestFromJson`), `synth.hpp` (`infer`, `synthesise`, `params`,
`ensureContrast`), `solver.hpp` (`GateTable`, `validate`), `cache.hpp`
(`DiskCache`), `json.hpp` (wire JSON), `engine.hpp` (`Engine`). The
repository is C++20, so fallible calls return `Expected<T>`
(`expected.hpp`), a `std::variant<T, Error>` wrapper.

## Determinism and versions

Identical bytes and request give byte-identical JSON across runs, cache
states and thread counts. `kAlgorithm` (currently 1) changes whenever any
output byte changes; the same PR regenerates the goldens
(`CHROMATIC_UPDATE_GOLDEN=1 pytest tests/test_chromatic_golden.py`).
Across toolchains the golden test accepts colour drift up to ΔEOK 0.005
(RFC §15); `CHROMATIC_GOLDEN_STRICT=1` demands bytes.

## Tests

- `ctest -R chromatic` — colour maths against published values, gate
  table, every variant × mode × level from a seed, quantiser, transparency,
  cache round trip and corruption, unreadable inputs, request parsing.
- `tests/test_chromatic_cli.py` — verbs, shapes, exit codes, request
  files, cache equivalence, same-size file change detection.
- `tests/test_chromatic_properties.py` — corpus × 8 variants × 2 modes ×
  3 levels plus 64 manual seeds (4 032 palettes): every gate passes and
  config's `validate_scheme` accepts each scheme; corpus expectations from
  `tests/chromatic/cases.json`; byte-identical repeats.
- `tests/test_chromatic_golden.py` — 540 goldens (20 cases × 9 variants ×
  3 modes).
- `tests/test_chromatic_catalogue.py` — config's credited catalogue
  wallpapers: goldens for `auto` and `balanced`, and every variant × mode
  accepted by `validate_scheme`.
- `tests/test_chromatic_fuzz.py` — truncated, bit-flipped and disguised
  inputs end with exit 0 or 3, never a crash.
- `tests/test_chromatic_perf.py` — RFC §14 budgets, failing at 3×.
- `tests/test_chromatic_gates_sync.py` — vendored gate table equals config
  at the pinned commit.
- `chromatic-bench --sweep` — 34 560 seed palettes (72 hues × 5 chromas ×
  2 cue sources × 8 variants × 2 modes × 3 levels); exits 1 on any failure.

The engine suites need the built binaries:
`HORNERO_CHROMATIC_BIN`, `HORNERO_CHROMATIC_CORPUS`,
`HORNERO_CHROMATIC_BENCH`, optional `HORNERO_CONFIG_DIR` (a config
checkout) and `HORNERO_CHROMATIC_SCRATCH`; without them they skip. CI's
`build` job sets them.

## Deviations from the RFC text

- **Seed share threshold** 0.002 instead of 0.005: RFC §4.4 requires a 0.3 %
  dot on grey to win, which a 0.005 threshold forbids.
- **Separation** follows config's gate table (ΔEOK and hue on three
  pairs), which is stricter than the RFC's 30° rotation alone; the extra
  search in step 10 is what makes every palette pass.
- **Grey manual seeds** (chroma below 0.02) borrow the house hue at chroma
  0.06, like achromatic images; `faithful` keeps the cue at chroma ≥ 0.08.
- The 30° anchor rotation targets 31° so the rule survives 8-bit rounding.
- Palettes are not cached on disk (synthesis from a cached analysis costs
  under a millisecond); only analyses and video frames are.

## Performance

Measured on the development host (x86-64, GCC 16, Qt 6.12, release with
debug info), median of 5; CI enforces 3× the budget:

| Operation | Budget | Measured |
| --- | --- | --- |
| Decode + analyse 4K JPEG | 60 ms | 19 ms |
| Decode + analyse 4K PNG | 150 ms | 109 ms |
| Synthesis + solver from a cached analysis | 2 ms | 0.37 ms |
| Helper end-to-end, cache hit | 20 ms | 8.3 ms |
| Helper peak memory 4K / 8K PNG | 96 / 220 MB | 75 / 169 MB |
