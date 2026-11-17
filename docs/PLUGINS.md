# Hornero Shell extension contract

**Status: PluginKit 3 (Hornero Signal).** The Shell discovers plugins that
`horneroctl plugin list` reports as enabled and installed, then instantiates
each manifest entrypoint in its own Loader
(`modules/plugins/PluginHost.qml`, state in `services/Plugins.qml`; inspect
with `qs ipc call plugins status` and rediscover with
`qs ipc call plugins reload`). `horneroctl plugin ...` owns install, enable,
disable, trust, and remove. Enabling revalidates the installed payload. The
Control Center can trust and enable with explicit confirmation; install,
update, and remove remain CLI actions.

Background plugins (the default) run headless. `placement: "bar"` renders in
the bar's islands; `placement: "dashboard"` renders in the dashboard
Extensions tab; `placement: "desktop"` renders a **desktop widget** on each
display's desktop layer (see [Desktop widgets](#desktop-widgets)). Each
plugin gets a separate Loader so one failure does not take down the shell
or neighbouring extensions. The `surfaces` map lets one package render on
several of those places at once — see
[Manifest: multiple surfaces](#manifest-multiple-surfaces) below.

PluginKit 3 is the Hornero Signal contract (RFC 0001): extensions use the
same colour roles, IBM Plex type, Hornero Glyphs, motion names and
instrument components as native surfaces, so a bar indicator, a dashboard
card and a desktop widget read as part of the shell. It is an intentional
**breaking** change from the Material-era kit: manifests must declare
`"schemaVersion": 3`, and packages built for PluginKit 1/2 are refused with
a pointer to [Migrating to PluginKit 3](#migrating-to-pluginkit-3) instead
of failing with an obscure QML error or blank glyphs.

The package installs the stable `Hornero.PluginKit` QML module. It exposes
`Settings`, `Translations`, `Theme`, `Notifications`, `Desktop`, the data
facades `System`, `Network`, `Media`, `Weather`, `Time`, `Power`, `Audio`
and `Workspaces`, the shared history `Telemetry`, and the shared-provider
`Providers` / `Subscription` lease (see
[Shared data providers](#shared-data-providers)) without requiring plugins
to import Shell internals:

- `Settings { pluginId: "example-clock" }` reads and writes keys declared by
  the selected manifest ID. Defaults and types come from
  `capabilities.settings`; user values are stored under that ID in
  `$XDG_CONFIG_HOME/hornero/shell.json`. `resetValue(key)` and
  `resetAll()` remove stored values so the declared defaults apply again.
  The ID is a namespace selector, not
  proof of the caller's identity or an access boundary between extensions.
- `Translations { pluginId: "example-clock" }` resolves the package's
  own JSON catalogs for the shell (system) locale and falls back to
  the source strings. See [Translations](#translations).
- `Theme` exposes the Signal tokens — see [Theme](#theme).
- `Notifications.toast(summary, body, glyph)` shows a bounded in-shell
  toast (the third argument is a Hornero Glyph name). It does not create a
  persistent desktop notification.
- `Desktop.editing`, `Desktop.anchor(pluginId, screenName)` and
  `Desktop.geometry(pluginId, screenName)` read desktop widget state.
  Users change placement in Control Center or in desktop edit mode;
  plugin code has no PluginKit setter for widget geometry.
- `System` (read-only): `cpuName`, `cpuPerc`, `cores` (per-core 0–1),
  `cpuTemp` + `cpuTempAvailable`, `gpuAvailable`, `gpuName`, `gpuPerc`,
  `gpuTemp` + `gpuTempAvailable`, `memUsed`, `memTotal`, `memPerc` (KiB /
  fraction), `storagePerc`, `storageAvailable` and `disks`.
- `Network` (read-only): `downloadSpeed`, `uploadSpeed` (bytes/s),
  `downloadTotal`, `uploadTotal`, link state `connected`, `wifi`, `wired`,
  `signalStrength`, `ssid`, and `formatRate(bytesPerSecond)`. The SSID is
  personal data: show it where the person expects it (a popover), never
  on an always-visible desktop widget by default.
- `Media` (read-only): `hasPlayer`, `identity`, `title`, `artist`,
  `album`, `artUrl`, `isPlaying`, `position`, `length`, `lengthSupported`,
  `canGoNext`, `canGoPrevious`, `canTogglePlaying`, plus the only mutating
  calls `playPause()`, `previous()`, `next()` and `refreshPosition()`.
  Call transport only from a user-initiated handler; PluginKit never
  auto-plays.
- `Weather` (read-only): `ready`, `locationConfigured`, `temp`,
  `description`, `humidity`, `windSpeed`, `sunrise`, `sunset`,
  `lastError`, and `forecast`.
- `Time` (read-only): `date`, `hours`, `minutes`, `seconds`, `timeStr`,
  plus `format(fmt)`.
- `Power` (read-only, from UPower): `hasBattery`, `percentage` (int
  0–100), `charging`, `onBattery`, `stateText`, `timeToEmpty`,
  `timeToFull` (s), `energyRate` (W), `healthAvailable` + `health`
  (capacity vs design, %), and `profile` (power profile).
- `Audio`: read-only `volume`, `muted`, `sourceVolume`, `sourceMuted`,
  `hasSink`, `hasSource`, `outputName`, `inputName`, `streamCount` and
  `spectrum` (shared visualiser bands, 0–1, real PipeWire data), plus the
  user-initiated controls `setVolume(v)`, `incrementVolume()`,
  `decrementVolume()`, `toggleMute()` and `toggleSourceMute()`. No
  PipeWire node object is exposed.
- `Workspaces`: `available`, `backend`, `activeWindowTitle`,
  `activeWindowAppId`, `forScreen(screenName)` → `[{id, label, active,
  occupied, special}]`, and the user-initiated `focus(screenName, id)`.
- `Telemetry`: shared sample history for instruments —
  `window(channel)`, `previousWindow(channel)`, `latest(channel)`,
  `peak(channel)` over the channels `cpu`, `gpu`, `mem`, `cpuTemp`,
  `gpuTemp`, `netDown`, `netUp` (see
  [Instrumentation](#instrumentation)).

All data facades are read-only except the Media transport, Audio and
Workspaces calls above. They have no other setters, no `Process`, and no
shell execution; they wrap only the shell's existing `qs.services`
singletons, plus Quickshell's `UPower`. They are QML running in-process:
they are **not sandboxed**. Declared `capabilities` (including
`providers`) are review-only disclosures, not runtime enforcement. No AI
quota is exposed by PluginKit; any AI quota is unknown and must not be
assumed or displayed as a known value.

## Theme

`Theme` carries exactly the shell's Signal tokens (RFC 0001 §3), under the
same names the shell uses:

| Token | Values |
| --- | --- |
| `Theme.palette.<role>` | `ground` `sunken` `base` `panel` `raised` `lifted` · `ink` `inkMuted` `inkFaint` · `rule` `ruleStrong` `focus` · `signal`/`onSignal`/`signalWell`/`onSignalWell` · `cue…` · `phosphor…` · `alert…` · `inverse` `onInverse` `inverseSignal` · `scrim` `shadow` · `glow` |
| `Theme.font.family.<f>` | `sans` (IBM Plex Sans), `mono` (IBM Plex Mono), `display` (IBM Plex Sans Condensed) |
| `Theme.font.size.<s>` | `small` 11 · `smaller` 12 · `normal` 13 · `larger` 15 · `large` 18 · `extraLarge` 28 · `display` 56 (points, like native text) |
| `Theme.rounding.<r>` | `small` 3 · `normal` 5 · `large` 8 · `full` (only for genuinely circular things) |
| `Theme.spacing.<s>` | `small` 4 · `smaller` 8 · `normal` 12 · `larger` 16 · `large` 24 |
| `Theme.padding.<p>` | `small` 4 · `smaller` 6 · `normal` 8 · `larger` 12 · `large` 16 |
| `Theme.anim.curves.<c>` | `standard` `enter` `exit` `sweep` `settle` `settleFast` |
| `Theme.duration(name)` | `quick` 90 · `short` 160 · `medium` 240 · `long` 360 · `scan` 480 · `settleFast` 220 · `settle` 320 · `fade` (ms; 0 under reduced motion except `fade` ≤ 90) |
| `Theme.light`, `Theme.highContrast` | effective palette mode and the host's high-contrast override |
| `Theme.experience` | `focus` / `everyday` / `signal` / `gaming` / `studio` (RFC §5a) |
| `Theme.motionLevel`, `Theme.reducedMotion` | `full` / `standard` / `reduced` / `off`; reduced motion forces `off` |
| `Theme.glowEnabled`, `Theme.scanlines` | luminous accent gate: only in the `signal` experience, dark themes, not high contrast, motion allowed |
| `Theme.telemetryIntervalMs` | shared instrument cadence: 1000 (500 in `signal`) |
| `Theme.keyboardFocus` | true when the last input was the keyboard (focus rings show only then) |

Rules of the language, enforced by review and partly by the validator:
`signal` (amber) means *live / active / primary* and `cue` (celeste) means
*focus / selection / information*; numbers use tabular figures; panels are
`panel` with a 1 px `rule` border and radius 3, never pills or glass;
`inkFaint` is decorative only; glow is never drawn by hand (instruments
apply it); nothing blinks or pulses. See the
[Signal visual language](https://github.com/HorneroOS/docs/blob/main/development/signal-visual-language.md).

## Migrating to PluginKit 3

PluginKit 3 removes the Material-era API outright — there is no
compatibility layer. `scripts/validate_plugin.py` rejects every removed
name with its replacement, so a port is mechanical:

1. Set `"schemaVersion": 3` in `manifest.json`.
2. Colours: `Theme.primary` → `Theme.palette.signal`,
   `Theme.onPrimary` → `Theme.palette.onSignal`,
   `Theme.primaryContainer` → `Theme.palette.signalWell`,
   `Theme.secondary*` → `Theme.palette.cue*`, `Theme.tertiary*` and
   `Theme.success` → `Theme.palette.phosphor*`, `Theme.error*` →
   `Theme.palette.alert*` (`*Container` → `*Well`),
   `Theme.surface` → `base`, `surfaceContainer` → `panel`,
   `surfaceContainerLow` → `sunken`, `surfaceContainerHigh` → `raised`,
   `surfaceContainerHighest` → `lifted`, `onSurface` → `ink`,
   `onSurfaceVariant` → `inkMuted`, `outline`/`componentBorder` →
   `ruleStrong`, `outlineVariant` → `rule`, `focusRing` → `focus`.
3. Tokens became groups: `Theme.spacingSmall` → `Theme.spacing.small`,
   `Theme.spacing` → `Theme.spacing.normal`, `Theme.rounding` →
   `Theme.rounding.normal`, `Theme.fontFamily` →
   `Theme.font.family.sans`, `Theme.fontSize*` → `Theme.font.size.*`,
   `Theme.durationNormal` → `Theme.duration("medium")`,
   `Theme.motionDuration(ms)` → `Theme.duration(name)`.
4. Glyphs: `UiIcon { icon: … }` → `UiIcon { name: … }`,
   `UiButton { iconName: … }` → `glyph`, `UiActionRow { iconName,
   trailingIconName }` → `glyph`, `trailingGlyph`, `UiCard { icon }` →
   `glyph`. Values are Hornero Glyph names (Tabler outline, kebab-case);
   Material names such as `graphic_eq` are rejected. Remove every
   `iconFill` / `fill:` axis — glyphs are outline-only; express state with
   colour or an on-air chip.
5. Variants: `UiButton` `ghost` → `quiet`, `tonal`/`outlined` →
   `secondary` (the default); `UiChip` tones `primary` → `signal`,
   `error` → `alert`. `UiStateLayer` is gone (no ripples).
6. Declare the data domains you read in `capabilities.providers` (below).

## Shared data providers

The data facades are presentation over shared, single-instance providers
(RFC 0001 §5b, shell#377): each domain is backed by exactly one
shell-owned service, so N extensions reading the same domain never
duplicate its timers, file reads, or child processes. Declare interest
with a `Subscription` lease so polling domains stay live while your
surface is loaded, and declare every domain you read in the manifest:

```json
"capabilities": { "processCommands": [], "networkHosts": [], "settings": {},
                  "providers": ["system", "network"] }
```

```qml
import QtQuick
import Hornero.PluginKit

Item {
    Subscription { domain: "system" }
    UiMetric { label: "CPU"; value: Math.round(System.cpuPerc * 100); unit: "%" }
}
```

| Domain | Facade | Mode | Refresh |
| --- | --- | --- | --- |
| `system` | `System`, `Telemetry` | polling | one shared timer while referenced: `/proc` reads at the experience cadence (1 Hz everyday, 2 Hz `signal`); `sensors`/GPU/`lsblk` probes at `dashboard.resourceUpdateInterval` (default 1000 ms) |
| `network` | `Network`, `Telemetry` | polling | one shared `/proc/net/dev` read at the experience cadence |
| `spectrum` | `Audio.spectrum` | stream | the shared PipeWire visualiser, running only while a lease is held |
| `weather` | `Weather` | cached | one shared fetch per configured location; refreshed hourly |
| `media` | `Media` | event | pushed by MPRIS |
| `time` | `Time` | event | pushed by the system clock |
| `power` | `Power` | event | pushed by UPower |
| `audio` | `Audio` | event | pushed by PipeWire |
| `workspaces` | `Workspaces` | event | pushed by the compositor (Hyprland or niri) |

Semantics every extension can rely on:

- **Permissions.** `capabilities.providers` lists the domains the package
  reads; the validator rejects a facade or `Subscription` domain the
  manifest does not declare. Like every capability, the declaration is
  disclosure for review, not enforcement (extension QML is not sandboxed).
- **One source per domain.** `system` and `network` are the only polling
  domains, and each owns exactly one timer gated on a reference count.
  A `Subscription` forwards one reference to that gate; it never creates a
  timer, process, or file poll of its own. Ten subscribers cost the same
  wakeups as one.
- **Cadence follows the experience.** While any extension holds a
  `system`/`network` lease the cheap `/proc` reads run at
  `Theme.telemetryIntervalMs`; in the `gaming` experience they fall back
  to the configured interval and desktop widgets are suspended (their
  leases released) until the mode changes.
- **Never invented.** Facade values are whatever the service last read.
  Sensors that do not exist report their availability flag as false
  (`System.cpuTempAvailable`, `gpuAvailable`, `Power.hasBattery`,
  `healthAvailable`, …): render "unavailable", never 0. Telemetry history
  records nothing for an unavailable channel.
- **Caching and backoff.** Without any lease, polling domains stop and
  reads return the last-known values; there is no per-plugin rate or
  exponential backoff to tune — polling runs at the one shared cadence
  while referenced and stops entirely at zero references. A failed sample
  keeps the previous values and is retried on the next shared tick; a
  failed weather fetch records `Weather.lastError` and retries hourly.
- **Release.** Disabling an extension releases its subscriptions: the host
  destroys its items, and `Subscription` unsubscribes from
  `Component.onDestruction`; an unsubscribe with no matching lease is
  refused.

The imperative form lives on `Providers`: `subscribe(domain)`,
`unsubscribe(domain)`, `subscriberCount(domain)`, `active(domain)`,
`mode(domain)`, `refreshIntervalMs(domain)` and `cost(domain)`. Prefer
`Subscription` — it cannot leak a lease.

### Instrumentation cost

`Providers.cost(domain)` (and `qs ipc call plugins telemetry`) reports the
samples taken and the mean PluginKit-side handling time per sample, so the
JS cost of the shared history is measured, not assumed. The services' own
`/proc` reads and probes are measured on the host as process CPU with and
without instrumentation widgets; record that measurement, labelled as a
host measurement, in the PR that changes instrumentation.

## UI primitives

All primitives use only `Theme` tokens, draw the Signal Bezel language
(matte modules, hairlines, small radii, tabular numerals) and carry the
keyboard/accessibility contract.

| Type | Purpose | Key properties |
| --- | --- | --- |
| `UiText` | Typography | `role`: `body` / `caption` / `subtitle` / `title` / `eyebrow` / `value` / `readout` / `display` |
| `UiEyebrow` | Section label | `text`, `channel` (`02 · TELEMETRY`), `context` (right-aligned eyebrow) |
| `UiIcon` | Hornero Glyph | `name`, `size` (points; 0 = default), `color` |
| `UiCard` | Instrument module | `title`, `channel`, `context`, `glyph`, `padding`; registration tick while focus is inside |
| `UiWell` | Sunken readout well | `padding`; default content slot |
| `UiButton` | Action button | `text`, `glyph`, `variant`: `secondary` (default) / `primary` / `quiet` / `danger`, `open`, `tooltipText`, `accessibleName` |
| `UiToggle` | Rocker switch | `value` (two-way with `checked`), `text`, `tooltipText`, `accessibleName`; inherits `toggled()` |
| `UiSlider` | Fader | `from`, `to`, `value`, `stepSize` (default 1/20 of the range), `tooltipText`, `accessibleName` |
| `UiMetric` | Large readout | `label`, `value`, `unit`, `available`, `tone`, `well`, `size` (`readout` / `display` / `value`) |
| `UiDetailRow` | Fact row | `label`, `value`, `available`, `glyph` |
| `UiActionRow` | Popout action row | `text`, `glyph`, `trailingGlyph`, `trailingText`, `selected`, `tooltipText`; `clicked()` |
| `UiChip` | Tag / on-air chip | `text`, `glyph`, `tone`: `neutral` / `signal` / `cue` / `phosphor` / `alert` / `live` |
| `UiProgress` | Task progress | `value` (0..1), `indeterminate` (static, never pulses), `tone` |
| `UiSegmentMeter` | Segmented meter | `value`, `available`, `count`, `orientation`, `threshold` (0.85), `critical` (sensor-reported only), `vu`, `peak` |
| `UiMeterRow` | Labelled meter row | `label`, `value`, `valueText`, `available`, `threshold`, `critical` |
| `UiSparkline` | Inline trace | `values`, `minimum`, `maximum` (≤ minimum = auto), `window`, `tone` (`cue` network, `phosphor` load, `signal` temperature), `glow` |
| `UiScope` | Oscilloscope well | `samples`, `previous` (persistence), `minimum`, `maximum`, `window`, `label`, `context`, `available`, `unavailableText`, `tone`, `glow` |
| `UiPartition` | Partition + dimension line | `total`, `used`, `secondary`, `usedLabel`, `secondaryLabel`, `available`, `knockout` |
| `UiState` | Empty / loading / error / unavailable | `kind`, `message`, `glyph` |
| `UiTooltip` | Host-owned tooltip | `target`, `text`, `delay` (500 ms), `timeout`, `preferredSide` |
| `UiPopover` | Host-owned anchored panel | `target`, `accessibleName`, `preferredSide`, `contentPadding`, `initialFocusItem`; `open()` / `close()` / `toggle()`, `actualSide` |
| `UiStack` | Adaptive row/column | `orientation`, `compact`, `spacing` |

### Icons: Hornero Glyphs

`UiIcon { name }`, `UiButton { glyph }`, `UiActionRow { glyph,
trailingGlyph }`, `UiCard`/`UiChip`/`UiDetailRow { glyph }`, a launcher
provider's `icon` and the third argument of `Notifications.toast()` take a
**Hornero Glyph name**: the curated Tabler Icons outline subset bundled
with the shell (`assets/fonts/hornero-glyphs.ttf`; the full list is
`assets/fonts/hornero-glyphs.names`, kebab-case, for example `wifi`,
`clock`, `calculator`, `wave-sine`, `player-play`). Glyphs are
outline-only — there is no fill axis. The validator rejects unknown and
Material-style names before install; at runtime an unknown name renders
nothing and logs one `Glyph: unknown glyph name` warning. Ask for a missing
glyph in a shell issue rather than shipping an icon font.

### Tooltips and popovers

Tooltips are host-owned: set `tooltipText` on `UiButton`, `UiToggle`,
`UiSlider` or `UiActionRow`, or attach a `UiTooltip { target: someItem;
text: "…" }` to any item. They show on hover **and** keyboard focus after
the same delay, Escape dismisses them until the trigger is left and
re-entered, and they stay clamped inside their surface. Tooltips are the
highest elevation (`lifted`, 1 px `ruleStrong`) and fade in 90 ms. The
text is also exposed as the trigger's accessible description. Never put
interactive content or essential-only information in a tooltip.

Popovers are host-owned too: a compact indicator (a bar `UiButton`) is
the `target` of a `UiPopover`, and the rich panel goes in its default
content slot. In a bar, the content is handed to the shell's native
popout panel — it opens on hover, grows from the bar edge and moves
between triggers exactly like native popouts (anchored-surface contract,
RFC 0001 §4); extensions never position themselves in screen
coordinates. Elsewhere (dashboard, desktop) the popover is a `panel`
surface with the **notch** — a 2 px `signal` line as wide as the trigger
on the edge facing it — that scans in 6 px from its anchor edge with
`enter`/short and leaves with 4 px travel back (`exit`/quick); reduced
motion keeps only a ≤ 90 ms fade. On open, focus moves into the panel
(`initialFocusItem`, else the first focusable control); Escape closes the
popover before any surface underneath (the Escape cascade) and returns
focus to the trigger. Set `accessibleName` on the popover and the trigger.

```qml
import QtQuick
import Hornero.PluginKit

Item {
    UiButton {
        id: indicator
        glyph: "music"
        accessibleName: "Media details"
        onClicked: popover.toggle()
    }
    UiPopover {
        id: popover
        target: indicator
        accessibleName: "Media details"
        Column {
            spacing: Theme.spacing.smaller
            UiEyebrow { channel: 1; text: "Now playing" }
            UiDetailRow { width: 320; label: "Track"; value: Media.title; available: Media.hasPlayer }
            UiButton { glyph: "player-play"; text: "Play/Pause"; onClicked: Media.playPause() }
        }
    }
}
```

### Anchored popovers and tooltips

Extension popovers and tooltips follow the shell's anchored-surface
contract (RFC 0001 §4; [INTERACTION.md](INTERACTION.md#anchored-surfaces)).
An extension never positions a surface in absolute screen coordinates;
it names a `target` and the host does the rest:

- **Bar indicators.** A `UiPopover` whose trigger lives in a bar is
  hosted by the bar's own popout surface. It opens on hover after the
  120 ms intent delay, grows from the trigger notch, morphs when the
  pointer moves to a neighbouring trigger, honours the 240 ms close
  grace, staggers its rows and closes with the same 90 ms fade as
  native popouts. Content is reparented visually only; the extension
  keeps ownership.
- **Elsewhere** (dashboard, desktop widgets), `UiPopover` and
  `UiTooltip` place themselves with `Placement.js`, a verbatim copy of
  the shell solver shipped inside `Hornero.PluginKit`: with
  `preferredSide: "auto"` a trigger inside a bar opens away from that
  bar (down from top bars, up from bottom bars, inward from rails), any
  other trigger prefers the free vertical half; an explicit side flips
  once when it would clip, the panel stays inside the screen minus an
  8 px gutter, and it follows its trigger across moves, resizes and
  scale changes.
- **Stable API.** `target`, `text`, `delay`, `timeout`,
  `preferredSide`, `accessibleName`, `contentPadding`,
  `initialFocusItem`, `open()`, `close()`, `toggle()`, `dismiss()`,
  `actualSide` and `placementFor(...)` keep their names and meanings;
  only the placement arithmetic moved to the shared solver.

## Instrumentation

Rainmeter/Conky-class desktops are built on PluginKit — there is no
second widget engine. Bar indicators, dashboard cards and desktop widgets
share the same components, tokens, motion and data providers. The
instrument components follow the visual language's real-data rule:

- Only real telemetry is drawn. Bind instruments to facades or
  `Telemetry`; when a source is unavailable pass `available: false` — the
  instrument shows an em dash in `inkMuted`, all segments off, and (for a
  scope) `unavailableText` naming what is missing. No placeholder waves,
  no idle animation, no interpolated samples.
- Every plot states its window and scale in an eyebrow
  (`CPU · 10 %/DIV`, `60 S WINDOW`).
- `UiScope` is the signature instrument: graticule, dashed centre line, a
  1.5 px `phosphor` trace and the previous window at 22 % as persistence.
  In the `signal` experience it gets the luminous accent (static 4 px halo
  at 40 % in `glow`) and faint static scanlines; at most three glowing
  items exist at once (a shared budget) and glow is off in day themes,
  high contrast, focus, gaming and with reduced motion.
- Meters threshold at 85 % to `signal`; `alert` only above a critical
  value the sensor itself reports. Vertical VU meters use `phosphor`.
- Plots shift on each sample with no tween; numerals update instantly.

Usage example:

```qml
import QtQuick
import Hornero.PluginKit

Column {
    spacing: Theme.spacing.normal
    Subscription { domain: "system" }
    UiScope {
        width: 360; height: 140
        label: "CPU · 10 %/DIV"
        context: Telemetry.windowSize + " SAMPLES"
        samples: Telemetry.window("cpu")
        previous: Telemetry.previousWindow("cpu")
    }
    UiMeterRow {
        width: 360
        label: "GPU"
        available: System.gpuAvailable
        value: System.gpuPerc
        valueText: Math.round(System.gpuPerc * 100) + " %"
    }
}
```

## Desktop widgets

A surface named `desktop` renders as a desktop widget on every display's
desktop layer (`modules/plugins/PluginDesktopWidgets.qml`, one
`DesktopWidgetFrame` per widget). The host owns the **module**: `panel`
fill, 1 px `rule` border, radius 3, the single elevation shadow and an
eyebrow header with a channel number (`02 · SYSTEM INSIGHT`). The
extension owns only its content, laid out in the host context box
(`hostAvailableWidth` × `hostAvailableHeight`). The entrypoint root may
declare `property string widgetTitle` (replaces the package name in the
header) and `property string widgetContext` (the right-hand eyebrow, e.g.
`60 S WINDOW`). Use `UiCard` freely inside: on the desktop it draws only
its header and content, never a second frame.

Geometry hints live on the desktop surface:

```json
"surfaces": {
  "desktop": { "entrypoint": "Desktop.qml", "width": 560, "height": 360,
               "minWidth": 420, "minHeight": 280, "resizable": true,
               "anchor": "top-left" }
}
```

- `width`/`height` are the default size and `minWidth`/`minHeight` the
  smallest the person can resize it to (80–1600 logical px);
  `resizable: false` hides the resize grip; `anchor` (one of nine
  positions) is where the widget starts. Without a size hint the widget
  takes its content's implicit size.
- **Edit mode.** `qs ipc call plugins editDesktop` (or `toggleEditDesktop`,
  `doneDesktop`) shows a toolbar, a dashed `cue` outline, whole-module
  drag, a corner resize grip and a live dimension readout. Positions snap
  to an 8 px grid. While editing, widget content does not take input.
- **Persistence.** Moves and resizes persist per display in
  `plugins.desktopWidgets` of the user's shell config as a fraction of the
  free space plus a logical size, so a resolution change keeps the layout
  and a disconnected display keeps its entry. Choosing an anchor in
  Control Center (`plugins.desktopWidgetSlots`) resets the free position
  to that anchor; *Reset layout* in the edit toolbar returns every widget
  on that display to its anchor and default size.
- **Experiences.** The `desktopWidgets` field of the active experience
  decides what the desktop layer holds ([EXPERIENCE.md](EXPERIENCE.md)):
  `user` shows the extensions the person enabled; `instruments` (the
  `signal` experience) shows the curated **Signal deck** instead (System
  Insight, Network Scope, Audio Deck, Calendar, Agenda, Moon Phase),
  placed per display by `services/deck.js` around the bar edge and the
  desktop clock, with registration marks at the module corners and the
  luminous accent on traces only (`GlowBudget`: three items, 4 px, 40 %,
  static). The deck loads installed first-party packages with a trusted
  payload without enabling them in Extensions; a missing or untrusted one is
  reported in Settings, Experience and simply not drawn. `none` (`focus`,
  `gaming`) instantiates no widget at all, so nothing draws and every
  provider lease is released and nothing polls for the desktop.
  Deck geometry is stored per mode in `experience.deck`, not in
  `plugins.desktopWidgets`.
- Desktop widgets live on the desktop layer, below windows; they never
  take keyboard focus from applications.

## Accessibility and keyboard contract

Extension UI follows the same keyboard/focus rules as native shell
UI (shell#376; the native-pane audit is shell#221). Using the
PluginKit controls gets the whole contract for free; hand-rolled
interactive items must provide it themselves.

- **Names and descriptions.** Every interactive control exposes an
  accessible name and role. `UiButton`/`UiToggle` default the name
  to their `text`; set `accessibleName` when the visible label is
  an icon, a glyph, or ambiguous out of context, and `tooltipText`
  doubles as the accessible description. `UiSlider` defaults to
  `Slider` — always give it a real name (what it adjusts).
  `UiPopover` exposes its `accessibleName` with the dialog role.
- **Tab order.** Deterministic: controls are single tab stops in
  declaration (visual) order, and disabled controls are not tab
  stops (`activeFocusOnTab: enabled` in the kit). Do not add extra
  tab stops around a control (no focusable wrappers); use
  `KeyNavigation` only to repair an order the layout cannot express.
- **Activation.** Enter, Return and Space all activate `UiButton`
  and toggle `UiToggle`. Escape dismisses the innermost transient
  first — tooltip, then popover, then the surface underneath (the
  Escape cascade) — and is accepted at the tier that handles it.
- **Arrows.** `UiSlider` arrows step by `stepSize` (default 1/20 of
  the range), PageUp/PageDown by 1/10, Home/End jump to the range
  ends. Plugin-defined lists/grids should use the same arrow +
  Enter/Space model with a single roving tab stop.
- **Visible focus.** The kit draws a 2 px contrasting border on the
  focused control. Custom controls must show an equally visible
  indication when `activeFocus` — use `Theme.palette.focus` for the
  host focus colour (2 px, 2 px outside the control, only while
  `Theme.keyboardFocus`) and never rely on hover styling alone.
- **Focus restoration.** Opening a `UiPopover` moves focus into it;
  closing it (Escape, or activating a control inside) returns focus
  to the trigger. Never leave focus on a hidden or destroyed item.
- **Reduced motion and high contrast are inherited.** Kit
  transitions already honour the host settings; for your own
  animations use the motion names — `Theme.duration(name)` with
  `Theme.anim.curves.<name>` (durations are 0 under reduced motion,
  except `fade` which stays ≤ 90 ms) — and never loop motion: nothing
  in Signal blinks or pulses. Settle curves move position/size only,
  never opacity or colour. Theme colours already swap to the
  high-contrast palette; `Theme.highContrast` is exposed for emphasis
  decisions. Do not hardcode colours or durations.
- **Custom interactive surfaces.** A `MouseArea` click with no
  keyboard path is a contract violation: prefer a kit control, or
  give the item an accessible name and role, `activeFocusOnTab`,
  visible focus, and Enter/Space handling in the same file.
  `scripts/validate_plugin.py` prints an `accessibility warning`
  for mouse-only actions (a warning, not a failure — already
  shipped plugins stay valid), and reviewers should treat new
  warnings as blocking.

The reference extensions under `examples/plugins/` follow this
contract, and `tests/qa/tst_pluginkit_keyboard.qml` drives a
reference surface keyboard-only (tab order, Enter/Space, slider
keys, popover open/Escape/focus-return) in an offscreen QML probe
run by `tests/test_pluginkit_ui.py`. That probe is QML-level
evidence only: live compositor focus grabs and screen-reader
(AT-SPI) announcements still need a running session to verify, so
shell#221's live audit remains the owner of those claims.

## Bar islands and sections

Bar indicators do not form a separate block: they live in the bar's
islands, styled like their native neighbours.

- **Extensions island** — the bar entry `extensions` (in the default
  layout and the presets, next to `tray`) is an island with the same
  chip, transitions and compact behaviour as the system tray. It carries
  exactly the tray's settings, with the same defaults: background,
  compact and recolour toggles in Control Center → Taskbar →
  *Extensions Settings*, plus the same config-file keys
  (`bar.extensions.*` mirrors `bar.tray.*` in `BarConfig` and in the
  persisted config; `hiddenIcons` lists plugin ids the island does
  not render). Layouts without the entry
  render the same island at the end of the end group — never a bare
  stack of indicators — so the settings apply in every layout.
- **Native sections** — a bar surface may declare
  `"section": "status" | "actions" | "clock" | "end"` (default `end`,
  i.e. the Extensions island). `status` joins the status icons island,
  `actions` the quick actions island, `clock` the clock island. The
  island's host advertises its icon colour and sizes; PluginKit
  `UiButton`/`UiIcon` adopt them, so a glyph-only indicator
  (`glyph`) matches the native glyphs around it. If the target island
  is not in the current layout, the indicator falls back to the
  Extensions island. `section` is bar-only and enforced by the schema,
  `scripts/validate_plugin.py` and the runtime host.

## Host context

The same plugin must render correctly in a horizontal top/bottom
bar, a vertical left/right rail, a dashboard card and a desktop card
without hardcoding sizes. The host that renders a placement knows
which surface that is, so it injects this context into the
entrypoint root. Injection is opt-in and additive: declare any of
these properties on the entrypoint's root item and the host keeps
them bound to the real surface values (live across edge, thickness
and layout changes); declare none and nothing changes — every
previously shipped plugin keeps working unchanged. Always give the
properties defaults that match your current layout, so the plugin
also renders sensibly before/without injection.

| Property | Type | Meaning |
| --- | --- | --- |
| `hostOrientation` | `string` | `horizontal` or `vertical` main axis of the surface |
| `hostEdge` | `string` | Bar edge: `top` / `bottom` / `left` / `right`; `none` on edge-less surfaces (dashboard, desktop) |
| `hostSurface` | `string` | `bar` / `dashboard` / `desktop` |
| `hostAvailableWidth` | `int` | Logical pixels the host allows on the width axis — exactly the cap it enforces, so honouring it means no clipping (0 = uncapped) |
| `hostAvailableHeight` | `int` | Same for height (0 = uncapped, e.g. scrolling dashboard cards) |
| `hostCompact` | `bool` | Narrow surface: any vertical rail, or a horizontal bar under the shell's compact width breakpoint. Drop secondary labels and stack rows when set |
| `hostScreenName` | `string` | Display hosting this instance (a bar/desktop plugin is instantiated once per screen); empty when not screen-bound |

Sizes are logical pixels, already corrected for output scale by Qt,
so one layout serves every scale. On the bar, the cross-axis
available size is the bar's configured content thickness and the
main-axis cap is 240; dashboard cards report 380 wide with uncapped
height; desktop widgets report their frame's content box (both axes,
live while the person resizes the widget in edit mode).

Never force a horizontal multi-button row into a vertical rail:
bind a `UiStack` to the context and it stacks for you.

```qml
import QtQuick
import Hornero.PluginKit

Item {
    // Opt in to host context; defaults = roomy horizontal surface.
    property string hostOrientation: "horizontal"
    property bool hostCompact: false
    property int hostAvailableWidth: 0

    implicitWidth: stack.implicitWidth
    implicitHeight: stack.implicitHeight

    UiStack {
        id: stack
        orientation: parent.hostOrientation
        compact: parent.hostCompact
        UiButton { text: "Play"; accessibleName: "Play"; onClicked: Media.playPause() }
        UiButton { text: "Next"; accessibleName: "Next track"; onClicked: Media.next() }
    }
}
```

`examples/plugins/example-clock` shows the minimal opt-in (it drops
the weekday when `hostCompact`). Evidence note: this contract is
covered by unit/host tests (`tests/test_plugin_host_context.py`)
over all four edges and surfaces; no live compositor run on
multi-monitor hardware backs it yet, so treat on-screen behaviour at
unusual scales as contract-tested, not compositor-verified.

The manifest schema is
[`schemas/plugin-manifest.schema.json`](../schemas/plugin-manifest.schema.json)
and the local checker is `scripts/validate_plugin.py`.

## Translations

A package can ship its own translations without any C++ or build
step. Declare them in the manifest (optional in every
`schemaVersion`; packages without the field behave exactly as
before):

```json
"translations": {
  "sourceLocale": "en",
  "locales": ["es"],
  "directory": "translations"
}
```

- `sourceLocale` is the language of the strings written in your QML
  (Qt locale tag: `en`, `es_AR`, `pt_BR`, …). It needs no catalog —
  the strings in code are that locale's text.
- `locales` lists the locales you ship a catalog for. Each catalog
  is a flat JSON object at `<directory>/<locale>.json` mapping each
  source string to its translation, and must be listed in `files`:

  ```json
  { "Example Clock": "Reloj de ejemplo", "Today is %1": "Hoy es %1" }
  ```

- `directory` is optional and defaults to `"translations"`.

Read strings through PluginKit `Translations`, which mirrors the
`Settings` shape:

```qml
import Hornero.PluginKit

Translations { id: i18n; pluginId: "example-clock" }

Text { text: i18n.tr("Example Clock") }
Text { text: i18n.tr("Today is %1").arg(i18n.formatDateTime(new Date(), "dddd, d MMMM")) }
```

Locale selection follows the shell locale: the system locale the
shell itself runs with (`Qt.locale()`, derived from `LANG`/`LC_*`;
the shell has no separate language override yet, and this component
will follow one through its `localeName` property if that changes).
Resolution tries the full tag first, then its language — an
`es_AR` system loads `es_AR.json` when shipped, else `es.json` —
and otherwise falls back to the source strings exactly as written.
A missing or malformed catalog degrades to source strings; it never
fails the plugin. `i18n.ready` and `i18n.resolvedLocale` report the
resolution state, and `i18n.formatDateTime(...)` /
`i18n.formatNumber(...)` format with the resolved locale so weekday
names, date order, decimal separators, and grouping match the
language on screen.

Rules the validator and the runtime host enforce:

- Catalogs are plain JSON so reviewers can read them like the rest
  of the package. Compiled Qt Linguist `.qm` files are rejected as
  compiled payload, and the shell installs no `QTranslator` for
  plugins — which is why `qsTr()` in plugin QML is also rejected:
  in the shell's own QML `qsTr()` marks strings for a catalog the
  shell does not ship yet (they render as source text), and in a
  plugin it would likewise never translate. Use `tr()` above.
- Every literal string passed to `tr("...")` must have a non-empty
  entry in every declared locale's catalog, keeping the same
  `%1`/`%2` placeholders as the source string. Omit a string from a
  catalog only by not declaring that locale yet — a declared locale
  must be complete for literal strings. (Strings built dynamically
  cannot be extracted statically; covering them is on the author,
  and `tr()` falls back to the source text when a key is absent.)
- Long entries are fine (keys and values up to 4000 characters);
  empty translations are not. Design layouts for text expansion:
  Spanish strings commonly run ~20–30% longer than English, so
  prefer the PluginKit UI primitives' wrapping/eliding behaviour
  over fixed widths.

`examples/plugins/example-clock` demonstrates the whole path:
English source strings, a Spanish catalog with natural Argentine
Spanish, locale-aware weekday formatting, and a `%1` placeholder.
Translating the first-party catalogue in `HorneroOS/plugins` to the
ES/EN baseline is tracked there (plugins#21 audit: 32 shipped
plugins had no translation calls at all); this contract is the
platform they migrate onto, plugin by plugin, rather than a claim
that the catalogue is already translated.

## Trust boundary

Quickshell QML executes with the logged-in user's permissions. Hornero Shell
does not sandbox QML, and a manifest declaration cannot restrict filesystem,
process, or network access at runtime. The validator catches a conservative
set of malformed packages and suspicious source patterns; passing it is not a
security certification. PluginKit's settings namespace does not isolate one
extension from another. Review source before running a community extension.
Never put credentials, privileged helpers, compiled binaries, or personal
configuration into an extension package.

## Package shape

Each package contains one `manifest.json`, the declared QML entrypoint, and
exactly the files listed in `files`. Paths are package-relative and may not
escape the package. Symlinks, compiled binaries, bytecode, setuid/setgid bits,
world-writable files, and executable files are rejected. A package must carry
its own README and license when it is distributed; the checker does not infer
or approve SPDX license identifiers.

Minimal manifest:

```json
{
  "schemaVersion": 3,
  "id": "example-clock",
  "name": "Example Clock",
  "version": "1.0.0",
  "description": "A sample clock card.",
  "author": "Example Author",
  "license": "MIT",
  "entrypoint": "Main.qml",
  "files": ["Main.qml", "README.md", "LICENSE"],
  "capabilities": {
    "processCommands": [],
    "networkHosts": [],
    "settings": {}
  }
}
```

`placement` is optional: `"background"` (default, headless),
`"bar"` (rendered in the bar's islands), or `"dashboard"`
(rendered as a card in the dashboard Extensions tab), or `"desktop"`
(a [desktop widget](#desktop-widgets) on each display's desktop layer).
Unknown values are rejected by the validator and by the runtime host.

Use `processCommands` to disclose exact executable basenames,
`networkHosts` to disclose intended network hosts, and the optional
`providers` list to disclose the [shared data domains](#shared-data-providers)
the extension reads. These fields support code
review only; they are not an operating-system permission grant. Settings are
typed metadata with explicit defaults. The host owns persistence and exposes
settings through PluginKit; extensions cannot write the canonical shell
config through that API.

The optional `capabilities.actions` list declares `horneroctl plugin action`
broker action names (snake_case, e.g. `system_info`, `notify`) the extension
may request through the typed capability broker (HorneroOS/hornero#408).
Like the other capability fields it is a declaration, not a grant: the broker
enforces payload trust, this declaration, typed arguments and ABAC at call
time, and refuses undeclared actions. Catalogue membership is checked by the
broker, so new broker actions need no manifest migration.

## Extension settings: typed schema and generated UI

Settings are declared in `capabilities.settings`, keyed by a camelCase
setting ID (`^[a-z][a-zA-Z0-9]{0,47}$`). Each declaration is
`type` + `default`, with an optional `description` (shown in Control
Center under the field, as the control's accessible description, and
as its tooltip where the control supports one) and the constraints
for its type:

| Type | `default` | Constraints | Generated control |
| --- | --- | --- | --- |
| `boolean` | `true` / `false` | — | Switch |
| `integer` | integer | `minimum`, `maximum` (integers) | Spin box, plus a slider when both bounds are declared |
| `number` | finite number | `minimum`, `maximum` | Spin box, plus a slider when both bounds are declared |
| `string` | string (max 4096 chars) | `minLength`, `maxLength` (0–4096) | Text field |
| `enum` | one of `options` | `options` (required: 1–32 unique non-empty strings, max 64 chars each) | One toggle button per option |

```json
"settings": {
  "twentyFourHour": { "type": "boolean", "default": true, "description": "Use 24-hour time." },
  "refreshMinutes": { "type": "integer", "default": 15, "minimum": 1, "maximum": 120 },
  "opacity": { "type": "number", "default": 0.9, "minimum": 0.1, "maximum": 1 },
  "label": { "type": "string", "default": "Weather", "maxLength": 40 },
  "units": { "type": "enum", "default": "metric", "options": ["metric", "imperial"] }
}
```

The type set is closed. Constraint fields on the wrong type, unknown
fields, `minimum > maximum`, `minLength > maxLength`, a default
outside its own range/length, and an enum default missing from
`options` are all rejected by the schema/validator (cross-field
rules live in `scripts/validate_plugin.py` and are mirrored by the
runtime in `services/Plugins.qml`, which drops malformed
declarations before the facade or UI can see them). There is
deliberately **no path type**: settings are plain Shell-owned values
in `shell.json`, never filesystem paths the shell opens, so no
setting can escape the user's config dirs through this contract. A
`string` setting is just a string; what plugin code does with it is
covered by the trust boundary above, not by this schema.

Control Center › Extensions generates one field per declared setting
(sorted by key) from these declarations — plugins get a consistent,
validated, keyboard-accessible settings UI with no settings code of
their own, and a plugin that declares no (valid) settings shows no
Settings affordance. Generated fields read and write the same
Shell-owned storage as the PluginKit `Settings` facade, validated
the same way, and each field offers Reset once a value is stored,
plus a confirmed Reset-all. Declare settings and stop there unless
a setting genuinely needs custom UI.

**Custom settings surface.** A manifest v2 package may additionally
declare `surfaces.settings` (Manifest v2, below) with its own
entrypoint. When the plugin is enabled and installed, Control
Center › Extensions loads that entrypoint in the plugin's Custom settings tab **alongside** the generated UI — it does not replace it, so
typed settings keep their validated controls and storage. The
custom surface is loaded only while that section is expanded, each
in its own asynchronous `Loader`: a failure marks the plugin failed
through the `Plugins` service (state plus bounded, redacted
diagnostics) and shows an inline error, never crashing Control
Center or another plugin, and disabling the plugin (or safe mode)
unloads it. Plugins without the surface see no change at all. The
generated UI does not need the surface; declare it only for UI the
typed controls cannot express. Honest trust note: the custom
surface is in-process QML running as your user, unsandboxed —
exactly the same trust as the plugin's other surfaces, not a
permission boundary.

**Migration.** Stored values are never rewritten by an update; they
are re-validated against the *current* declaration on every read. A
stored value that still satisfies its declaration keeps working
unchanged across manifest updates. Anything else — the type changed,
an enum option was removed, a range or length was tightened, the
stored shape is malformed — reads as the declared `default` (never
coerced, never a crash), and the next write or reset replaces it.
Renaming a setting key is therefore a new setting with its own
default; the old key's stored value is ignored. Reset
(`Settings.resetValue` / `resetAll`, or the generated UI) deletes
the stored value outright, so the default applies until the user
changes it again.

## Manifest: multiple surfaces

Manifest v2 introduced, and `"schemaVersion": 3` keeps, one optional
field, `surfaces`: a map from surface name to that surface's own entry
point. The top-level `entrypoint`/`placement` pair stays the package's
**primary surface**, so a manifest without `surfaces` loads exactly one
effective surface, the placement, loading the top-level entrypoint,
enabled. Those are the documented defaults. (Material-era schemaVersion 1
and 2 packages are refused; see
[Migrating to PluginKit 3](#migrating-to-pluginkit-3).)

```json
{
  "schemaVersion": 3,
  "id": "example-multi-surface",
  "name": "Example Multi-Surface",
  "version": "1.0.0",
  "description": "Bar indicator plus dashboard card from one package.",
  "author": "Example Author",
  "license": "MIT",
  "entrypoint": "Main.qml",
  "placement": "bar",
  "files": ["Main.qml", "Dashboard.qml", "Service.qml", "README.md", "LICENSE"],
  "surfaces": {
    "dashboard": { "entrypoint": "Dashboard.qml" },
    "background": { "entrypoint": "Service.qml", "enabled": false }
  },
  "capabilities": {
    "processCommands": [],
    "networkHosts": [],
    "settings": {}
  }
}
```

`examples/plugins/example-multi-surface` is this shape with real files.

| Surface | Meaning | Hosted today |
| --- | --- | --- |
| `bar` | Bar indicator in the bar end group. A bar popover/panel is shown from this surface with PluginKit `UiPopover`; it is not a separate surface. | Yes |
| `dashboard` | Card (with any detail content inside the card) in the dashboard Extensions tab. | Yes |
| `desktop` | [Desktop widget](#desktop-widgets) on each display's desktop layer; may declare `width`, `height`, `minWidth`, `minHeight`, `resizable`, `anchor`. | Yes |
| `background` | Headless entry point (timers, toasts); only declare it where a headless component is justified. | Yes |
| `launcher` | Launcher/search action entry point. | Yes — `PluginLauncherHost` loads it hidden and registers it into the launcher provider registry ([LAUNCHER.md](LAUNCHER.md)). Contract (query/result): root `Item` with settable string `query` and readonly var `result` = `{ok: bool, text: string}`; prefix is the plugin id minus a leading `hornero-`; copy-on-activate copies `result.text` (wl-copy, the calc convention — no plugin activation hook). In-process QML running as your user, unsandboxed, same trust as every other surface. |
| `settings` | Custom Control Center settings entry point. | Yes — Control Center › Extensions loads it in the plugin's Custom settings tab alongside the generated settings UI (above), which renders `capabilities.settings` without it. In-process QML, same trust as other surfaces. |

Each surface declares `entrypoint` (a safe package-relative `.qml` path that
must also appear in `files`) and may declare `enabled` (boolean, default
`true`). A surface with `"enabled": false` is not loaded by its host; the
package's other surfaces are unaffected, so each surface can be enabled
independently. Per-user surface toggles are not part of this contract yet;
`enabled` is the manifest default the hosts honour.

The `dashboard` surface may additionally declare two card hints
(shell#378): `size` — a preferred card size class, one of `compact`,
`standard` (the historic 380px card width) or `wide` — and `category`, a
short grouping label. Both are dashboard-only (declaring either on another
surface is rejected), both are hints, and `"Pinned"` is reserved. A v1
`placement: "dashboard"` plugin declares neither and renders as a standard
uncategorized card.

### Dashboard layout (shell#378)

The Extensions tab is a composable, vertically scrolling layout, not a
fixed grid. Cards group into sections — user-Pinned first, then categories
alphabetically, then uncategorized cards under "Other" — and the column
count follows the available width. `wide` cards span two columns (one on a
single-column dashboard); `compact` cards get a narrower width and report
`hostCompact: true` through the responsive host context. The arrangement
is computed once per model change (`modules/plugins/DashboardLayout.qml`),
and plugin Loaders stay asynchronous, so 33+ cards stay cheap.

The user's arrangement persists in shell config as
`plugins.dashboardLayout` (`{order: [pluginId], pinned: [pluginId],
sizes: {pluginId: class}}` in `$XDG_CONFIG_HOME/hornero/shell.json`),
written only through `Config.plugins` setters, and always wins over the
manifest hints. Malformed or stale entries degrade to manifest order.
Cards are keyboard-configurable: focus a card (Tab or plain arrows to
move between cards), then Ctrl+arrows reorder it, `P` pins/unpins it, and
`S` cycles its size class; PageUp/PageDown scroll. Plugin code gets no
setter for the user layout.

Redeclaring the primary surface inside `surfaces` is allowed only with the
same entrypoint (for example to set `enabled`); a different file for the
primary placement is a conflicting manifest and is rejected rather than
silently overriding the top-level entrypoint. Load state (`loaded` /
`failed`) is still tracked per plugin, not per surface.

Validation is strict but additive, and the schema
([`schemas/plugin-manifest.schema.json`](../schemas/plugin-manifest.schema.json)),
the static checker (`scripts/validate_plugin.py`), and the runtime host
agree: unknown `schemaVersion` values are rejected (only `3` exists;
`1` and `2` get the migration message), desktop geometry hints on any
other surface are rejected, and unknown top-level fields, unknown surface names,
unknown keys inside a surface, non-boolean `enabled`, empty `surfaces`, and
unsafe or unlisted surface entrypoints all fail with an actionable message.
Unknown extra fields are rejected, not ignored. One cross-field rule cannot be expressed in JSON Schema (a redeclared
primary surface must reuse the top-level entrypoint); the schema documents
it, and the checker and runtime host enforce it.

Declaring a surface grants no privilege and changes nothing about the trust
boundary above: surfaces and `capabilities` alike are declarations —
review metadata, not enforcement, and not a permission grant. A surface
entrypoint gets exactly the same host Loader, PluginKit API, and
user-privilege execution as the primary entrypoint; there is no arbitrary
private-shell mutation path, and a `launcher` declaration runs
only in `PluginLauncherHost` (hidden Loader, provider registry —
see [LAUNCHER.md](LAUNCHER.md)), a `settings` declaration only
in its Control Center host, above, and only for enabled,
installed plugins. Installing
or enabling a schemaVersion 3 package also requires a `horneroctl` build
that accepts schemaVersion 3; the shell-side contract here does not change
the CLI's own validation.

## Marketplace metadata: previews, compatibility, history, deprecation

A package may declare optional `marketplace` metadata (shell#379, any
schema version) that the Control Center Extensions pane renders without
executing plugin code. No entrypoint is ever loaded to show a preview:
the host reads `manifest.json` as text for every installed package —
enabled or disabled — and catalogue/community entries may carry the
same shape in the verified `horneroctl` JSON, normalized by the shell
on read. Absent or malformed metadata renders exactly as before.

```json
"marketplace": {
  "screenshots": [
    { "path": "previews/clock.png", "alt": "Clock in the bar" }
  ],
  "compatibility": { "minShellVersion": "1.0.0", "maxShellVersion": "2.0.0" },
  "changelog": [
    { "version": "1.1.0", "notes": "What changed, newest first." }
  ],
  "deprecation": { "message": "Unmaintained.", "replacedBy": "other-plugin" }
}
```

- `screenshots` (1–6) names static image files shipped in `files`
  (`.png`, `.jpg`, `.jpeg`, `.webp`, each with an optional accessible
  `alt`). QML, SVG and animated formats are rejected, so a preview is
  always a plain image. The pane shows the images for installed
  packages; a catalogue entry that is not installed yet has no local
  payload, so its screenshots are listed by caption until installed.
- `compatibility` declares an inclusive Hornero Shell version range
  (`minShellVersion` and/or `maxShellVersion`, semantic versions,
  minimum not exceeding maximum). It is review metadata shown to
  users; it does not gate loading.
- `changelog` (1–20 entries, newest first) is the version history:
  one `{version, notes}` per release, versions unique semver.
- `deprecation` presence alone means deprecated, with an optional
  `message` and a `replacedBy` plugin id (never the plugin itself).
  The pane warns on installed and catalogue rows, stops offering new
  installs of a deprecated catalogue entry, and offers a "View
  replacement" shortcut that surfaces the replacement in the
  installed list or catalogue. Already-installed copies keep their
  existing lifecycle untouched; nothing is auto-disabled or removed.
- The detail view adds plain-language permission explanations for the
  declared `capabilities` (programs it may start, hosts it may
  contact, broker actions, its own settings) next to the raw
  declarations, plus the existing Settings shortcut for plugins with
  typed settings. Explanations do not make declarations enforced
  permissions: enabled QML still runs as your user without a sandbox.
- Marketplace metadata never drives a lifecycle write. Rollback
  remains available only through the existing verified provenance
  contract — the catalogue `rollback_available` flag and the
  confirmed `horneroctl plugin catalog rollback` action (shell#251 /
  #366) — and deprecation neither enables nor alters it.

`examples/plugins/example-clock` shows the opt-in (one screenshot, a
minimum shell version, one changelog entry). Schema, checker and the
runtime host enforce the same closed shape; unknown fields are
rejected everywhere.

## Official and community catalogues

The Extensions pane keeps the first-party `HorneroOS/plugins` catalogue
separate from community entries. Community discovery calls
`horneroctl plugin community list`; the shell displays entries only after the
CLI verifies the detached registry signature against the system key at
`/etc/hornero/registry.pub`. The verified listing includes its index version,
source revision, plugin source revision, payload hash, and author-key
fingerprint. A registry signature proves publication by that registry. It
does not prove that HorneroOS reviewed the code or that the extension is safe.

The community pane is read-only. It does not install, update, enable, or roll
back community entries until the CLI preserves the exact verified revision,
payload hash, author fingerprint, and rollback provenance through that
lifecycle. If the key, signature, index, or `minisign` is unavailable, the
CLI fails closed and the pane shows the error rather than falling back to an
unsigned list. The product key is not shipped yet; see
[`hornero/docs/PLUGIN_REGISTRY.md`](https://github.com/HorneroOS/hornero/blob/main/docs/PLUGIN_REGISTRY.md)
for the current client boundary and maintainer gate.

The extension import surface is intentionally narrow: Qt Quick and Quickshell
public modules plus `Hornero.PluginKit`. Imports from Hornero's internal
implementation and unknown PluginKit submodules are rejected. The checker also
rejects obvious shell/privilege escalation patterns and undeclared literal
`Process` commands. These textual checks can be evaded by dynamic code and
must never be treated as a sandbox.

## Diagnostics, performance budget and safe mode

Each extension carries a load state (`pending`, `loaded`, `failed`,
`blocked`, `disabled`, `safe-mode`) in `services/Plugins.qml`, shown in
Control Center › Extensions and in `qs ipc call plugins status`. A
per-extension **Reload** action (also `qs ipc call plugins
reloadPlugin <id>`) re-instantiates one plugin without restarting the
shell; **Disable** stays the `horneroctl`-owned lifecycle action. Load
failures and reloads are kept in a bounded (50-event) diagnostics log;
error details are redacted for credential-looking values
(`token=…`, `password: …`, `Bearer …`, `api_key=…`) and truncated
before they are logged, stored, or shown, so diagnostics never need
to carry secrets.

Performance budgets are advisory diagnostics, never enforcement —
in-process QML cannot be preempted or sandboxed, so exceeding a
budget is flagged, not punished:

- **Slow load**: host-measured time from discovery/reload to the
  entrypoint reporting loaded/failed over 2000 ms flags `slow-load`.
- **Load churn**: 5 or more load attempts within 60 s flags
  `load-churn` (the host-visible half of excessive polling).
- **Polling**: plugin-internal `Timer`s are not observable at
  runtime, so `scripts/validate_plugin.py` statically warns
  (`performance warning:`, never a failure) on literal Timer
  intervals below 1000 ms. Prefer a PluginKit subscription/facade
  signal over sub-second polling.

**Safe mode** is the recovery path when a plugin makes the shell
unusable. Start the shell with `HORNERO_SAFE_MODE=1` (or persist
`"plugins": {"safeMode": true}` in the shell config, toggled from the
Extensions pane). While safe mode is on, hosts receive no entries at
all: no plugin manifest is parsed and no plugin QML is instantiated,
so a malformed manifest or crash-looping entrypoint cannot block
access to the Extensions pane — which is core shell UI, not a
plugin — where the broken extension can be disabled. Safe mode
itself never enables, disables, or removes anything. Be honest about
the limit: this isolates *load* failures (malformed manifest/JSON,
QML compile or instantiation errors, which each host already confines
to that plugin's own Loader); it does not sandbox a running plugin,
which still executes with the logged-in user's permissions.

**PluginKit version gate.** The shell resolves `Hornero.PluginKit` from
the QML import path (`/usr/lib/qt6/qml` for the package, or
`QML2_IMPORT_PATH`). A partial upgrade can leave the previous kit there,
which fails every extension with raw errors such as `UiTextField is not
a type`. `plugin/qml/Hornero/PluginKit/PluginKitInfo.qml` carries the
kit's `apiLevel` (3 for schemaVersion 3); `PluginHost` reads it at start
and, when the resolved kit is older than the Shell needs (a kit without
the marker reads as 0), hosts nothing and says so plainly: every enabled
extension is marked `failed` with the message, the Extensions pane shows
it as a banner, and `qs ipc call plugins status` reports
`kit: {level, required, compatible, message}`. Fix it by updating the
`hornero-shell` package or by starting the shell with
`QML2_IMPORT_PATH=<checkout>/plugin/qml`.

## Validate a package

```sh
python3 scripts/validate_plugin.py path/to/example-clock
python3 scripts/validate_plugin.py --info   # {"schemaVersions": [3], "pluginKit": 3}
```

`horneroctl plugin ...` runs the validator that matches the running Shell:
it prefers `scripts/validate_plugin.py` of the Shell tree being run, then
the packaged `/usr/lib/hornero/hornero-shell-plugin-validate`, and uses
only one whose `--info` lists schemaVersion 3
(`HORNERO_PLUGIN_VALIDATOR` overrides).

The checker is also covered by `tests/test_plugin_contract.py`. Registry
discovery does not enable plugins or bypass the receipt and consent checks in
`horneroctl`.

## Which config is my session actually running?

Real installs run the packaged config at
`/etc/xdg/quickshell/hornero/shell.qml` (installed by the
`hornero-shell` package). A git checkout of this repository — for
example in `~/.config/quickshell` — is **not** what a running session
answers on unless it is the config Quickshell was started with:
`horneroctl` resolves the packaged hornero config first, and a bare
`qs ipc ...` without `QS_CONFIG_PATH` may target a different config
than the checkout you just edited. Run `horneroctl shell status` to
see the config the CLI targets. Merged shell changes reach a live
session only when the `hornero-shell` AUR package is upgraded; to
run a checkout instead, start Quickshell with that config explicitly
(`QS_CONFIG_PATH=<checkout>/shell.qml`) and expect every IPC probe to
need the same path.
