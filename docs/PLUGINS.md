# Hornero Shell extension contract

**Status: runtime slice 4 (loader, three visible placements, and public PluginKit API).** The
Shell discovers plugins that `horneroctl plugin list` reports as enabled and
installed, then instantiates each manifest entrypoint in its own Loader
(`modules/plugins/PluginHost.qml`, state in `services/Plugins.qml`; inspect
with `qs ipc call plugins status` and rediscover with
`qs ipc call plugins reload`). `horneroctl plugin ...` owns install, enable,
disable, trust, and remove. Enabling revalidates the installed payload. The
Control Center can trust and enable with explicit confirmation; install,
update, and remove remain CLI actions.

Background plugins (the default) run headless. `placement: "bar"` renders in
the bar's end group; `placement: "dashboard"` renders in the dashboard
Extensions tab; `placement: "desktop"` renders on each display's background
layer. Each plugin gets a separate Loader so one failure does not take down
the shell or neighbouring extensions. Manifest v2 (`"schemaVersion": 2`)
can declare additional entry points in the `surfaces` map so one package
renders on several of those places at once — see
[Manifest v2: multiple surfaces](#manifest-v2-multiple-surfaces) below.
Schema version 1 manifests keep working unchanged. Desktop widgets use nine named slots
per display. Their locations persist in the user's shell config, reflow when
resolution changes, and remain saved while a display is disconnected. A new
or unrecognized display and malformed slot data fall back to `bottom-right`.
Users select a widget's vertical and horizontal slot in Control Center.

The package installs the stable `Hornero.PluginKit` QML module. It exposes
`Settings`, `Translations`, `Theme`, `Notifications`, `Desktop`, `System`, `Network`,
`Media`, `Weather`, `Time`, `Power`, `Audio`, and the shared-provider
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
- `Theme` exposes semantic colors and light-mode state. Token names form the
  compatibility contract; internal palette implementation may change.
- `Notifications.toast(summary, body, icon)` shows a bounded in-shell toast.
  It does not create a persistent desktop notification.
- `Desktop.position(pluginId, Screen.name)` reads the current named slot.
  Users change placement in Control Center; plugin code has no PluginKit
  setter for canonical widget positions.
- `System` is a read-only singleton: `cpuPerc`, `cpuTemp`, `gpuPerc`,
  `gpuTemp`, `memUsed`, `memTotal`, `memPerc`, `storagePerc`, and `disks`.
- `Network` is a read-only singleton: `downloadSpeed`, `uploadSpeed`,
  `downloadTotal`, and `uploadTotal`.
- `Media` is a read-only singleton (`hasPlayer`, `identity`, `title`,
  `artist`, `isPlaying`) plus the only mutating facade calls:
  `playPause()`, `previous()`, and `next()`. Call them only from a
  user-initiated handler; PluginKit never auto-plays.
- `Weather` is a read-only singleton: `ready`, `locationConfigured`,
  `temp`, `description`, `humidity`, `windSpeed`, `sunrise`, `sunset`,
  `lastError`, and `forecast`.
- `Time` is a read-only singleton (`date`, `hours`, `minutes`, `seconds`,
  `timeStr`) plus `format(fmt)`.
- `Power` is a read-only singleton: `hasBattery`, `percentage` (int
  0-100), `charging`, `onBattery`, and `stateText` (`charging`,
  `fully-charged`, `discharging`, `pending-charge`, or empty when no
  battery or state is known). It is the one facade that delegates to
  Quickshell's `UPower` service (`Quickshell.Services.UPower`, via
  `UPower.displayDevice` / `UPower.onBattery`) rather than a
  `qs.services` singleton, mirroring `modules/bar/components/Battery.qml`.
- `Audio` is a singleton over `qs.services` `Audio`: read-only `volume`,
  `muted`, `sourceVolume`, and `sourceMuted` (real/bool), plus `hasSink`
  and `hasSource`. It also exposes the user-initiated controls
  `setVolume(v)`, `incrementVolume()`, `decrementVolume()`,
  `toggleMute()`, and `toggleSourceMute()`, delegating to the service
  (increment/decrement use the service default step). Call them only from
  a user-initiated handler. No PipeWire node (`PwNode`) object is exposed,
  and there are no source-volume, sink/source-selection, or stream setters.

All seven data facades are read-only except Media transport and the
Audio controls above. They have no other setters, no `Process`, and no
shell execution; they wrap only the shell's
existing `qs.services` singletons, plus Quickshell's `UPower` for `Power`.
They are QML running in-process: they
are **not sandboxed**. Declared `capabilities` are review-only disclosures,
not runtime enforcement. No AI quota is exposed by PluginKit; any AI quota
is unknown and must not be assumed or displayed as a known value.

## Shared data providers

The seven data facades are presentation over shared, single-instance
providers (shell#377): each domain is backed by exactly one shell-owned
singleton, so N extensions reading the same domain never duplicate its
timers, file reads, or child processes. Declare interest with a
`Subscription` lease so polling domains stay live while your surface is
loaded:

```qml
import QtQuick
import Hornero.PluginKit

Item {
    Subscription { domain: "system" }
    UiMetric { label: "CPU"; value: Math.round(System.cpuPerc * 100) + "%" }
}
```

| Domain | Facade | Mode | Refresh |
| --- | --- | --- | --- |
| `system` | `System` | polling | one shared timer at `dashboard.resourceUpdateInterval` (default 1000 ms) while at least one lease or shell surface references it |
| `network` | `Network` | polling | the same shared interval, from its own single timer |
| `weather` | `Weather` | cached | one shared fetch per configured location; result cached, refreshed hourly |
| `media` | `Media` | event | pushed by MPRIS; never polled |
| `time` | `Time` | event | pushed by the system clock (second precision) |
| `power` | `Power` | event | pushed by UPower; never polled |
| `audio` | `Audio` | event | pushed by PipeWire; never polled |

Semantics every extension can rely on:

- **One source per domain.** `system` and `network` are the only polling
  domains, and each owns exactly one timer gated on a reference count.
  A `Subscription` forwards one reference to that gate; it never
  creates a timer, process, or file poll of its own. Ten subscribers
  cost the same wakeups as one.
- **Caching.** Facade properties always read the shared singleton's
  latest values. With no lease held by anyone, polling domains stop
  updating and reads return the last-known values (zeros before the
  first sample) — reading a facade without subscribing still works,
  exactly as it did before subscriptions existed. Weather keeps its
  last parsed result (and caches resolved city names) between fetches.
- **Backoff.** There is no per-plugin rate to tune and no exponential
  backoff to configure: polling runs at the one shared interval while
  referenced and stops entirely at zero references, which is the idle
  state backoff would approximate. A failed sample keeps the previous
  values and is retried on the next shared tick; a failed weather
  fetch records `Weather.lastError` and is retried on the next hourly
  refresh (or when the configured location changes).
- **Release.** Disabling an extension releases its subscriptions: the
  host destroys the plugin's items on unload/disable, and
  `Subscription` unsubscribes from `Component.onDestruction`. Setting
  `enabled: false` or changing `domain` releases the previous lease
  immediately. An `unsubscribe` with no matching lease is refused, so
  one extension can never drive a shared gate negative for the others.

The imperative form lives on the `Providers` singleton for code that
cannot declare an object: `Providers.subscribe(domain)`,
`Providers.unsubscribe(domain)`, `Providers.subscriberCount(domain)`,
`Providers.active(domain)`, `Providers.mode(domain)`, and
`Providers.refreshIntervalMs(domain)` (0 for event domains, -1 for an
unknown domain; unknown domains are rejected by `subscribe`).
Prefer `Subscription` — it cannot leak a lease.

Idle-cost accounting (static analysis of this tree, not a host
measurement): before shared providers, an extension that wanted live
CPU/network figures had to run its own timer and subprocess per
extension instance. Now the only timers that can drive those domains
are the two refCount-gated service timers above, independent of
extension count, and both are stopped when nothing references them.
`tests/test_plugin_shared_providers.py` pins that count. A host-side
idle CPU/wakeup measurement (e.g. `powertop` with several
telemetry extensions enabled, before/after) still belongs in the
change's PR description, labelled as a host measurement.

## UI primitives

PluginKit also exposes native extension design-system primitives
(`Hornero.PluginKit` 1.0). They use only `Theme` tokens — no hardcoded
colors — and interactive controls declare accessible names and a
visible focus indication. Indeterminate progress does not animate
unless `animated: true` is set (reduced-motion by default).

| Type | Purpose | Key properties |
| --- | --- | --- |
| `UiText` | Typography | `role`: `title` / `body` / `caption`, `text` |
| `UiCard` | Surface container | `padding`; default content slot |
| `UiButton` | Action button | `text`, `variant`: `primary` / `ghost`, `tooltipText`, `accessibleName` |
| `UiToggle` | Boolean switch | `value` (two-way synced with `checked`), `text`, `tooltipText`, `accessibleName`; inherits `toggled()` from `Switch`/`AbstractButton` (no argument — read `checked`/`value` in `onToggled`) |
| `UiSlider` | Range input | `from`, `to`, `value`, `stepSize` (keyboard step, defaults to 1/20 of the range), `tooltipText`, `accessibleName` (defaults to `Slider`) |
| `UiMetric` | Labelled metric | `label`, `value`, optional `unit` |
| `UiChip` | Small label chip | `text`, `tone`: `neutral` / `primary` / `error` |
| `UiProgress` | Progress bar | `value` (0..1), `indeterminate`, `animated` (default `false`) |
| `UiState` | State placeholder | `kind`: `loading` / `error` / `empty`, `message` |
| `UiTooltip` | Host-owned tooltip | `target` (required `Item`), `text`, `delay` (default 500 ms), `timeout` (0 = until trigger ends), `preferredSide`: `auto` / `above` / `below` / `left` / `right` |
| `UiPopover` | Host-owned anchored panel | `target` (required `Item`, the trigger/anchor), `accessibleName`, `preferredSide` (same values as `UiTooltip`), `contentPadding`, `initialFocusItem`; default content slot; `open()` / `close()` / `toggle()`, read-only-by-convention `actualSide` |
| `UiStack` | Adaptive row/column layout | `orientation` (`horizontal` / `vertical`), `compact`, `spacing`; children stack vertically when `orientation` is `vertical` or `compact` is set |

Tooltips are host-owned: set `tooltipText` on `UiButton`, `UiToggle` or
`UiSlider`, or attach a `UiTooltip { target: someItem; text: "…" }` to
any item. They show on hover **and** keyboard focus after the same
delay, Escape dismisses them until the trigger is left and re-entered,
and placement covers all four bar edges plus dashboard, popovers and
desktop surfaces — the side flips when it would clip and the tooltip
stays clamped inside its surface across moves, resizes and scale
changes. The text is also exposed as the trigger's accessible
description. Never put interactive content in a tooltip, and never
rely on one for essential information: anything a tooltip says must
also be visible (or otherwise available) elsewhere.

Popovers are host-owned too: a compact indicator (for example a bar
`UiButton`) is the `target` of a `UiPopover`, and the rich panel goes
in the popover's default content slot using the other `Ui*`
primitives. Never create an independent top-level window for this.
The host owns positioning (the same placement as `UiTooltip`:
left/right rails and top/bottom bars via `preferredSide: "auto"`, an
explicit side flips when it would clip, and the panel stays clamped
inside its surface across moves, resizes and scale changes), monitor
selection (the panel opens on the surface that already hosts the
trigger), and dismissal (Escape or a press outside the panel;
`open()`, `close()` and `toggle()` cover programmatic control, so
wire the trigger with `onClicked: popover.toggle()`). On open, focus
moves into the panel — to `initialFocusItem` when set, else the first
focusable control, else the panel itself — so Tab navigation works
with the native controls inside. Escape closes the popover first,
before any surface-level Escape handling underneath it (see the
Escape cascade), and returns focus to the trigger; a press outside
closes it without moving focus. Set `accessibleName` on the popover
(it is exposed with the dialog accessible role) and an
`accessibleName` on the trigger control.

```qml
import QtQuick
import Hornero.PluginKit

Item {
    UiButton {
        id: indicator
        text: "♪"
        accessibleName: "Media details"
        onClicked: popover.toggle()
    }
    UiPopover {
        id: popover
        target: indicator
        accessibleName: "Media details"
        Column {
            UiMetric { label: "Track"; value: Media.title }
            UiButton { text: "Play/Pause"; accessibleName: "Play or pause"; onClicked: Media.playPause() }
        }
    }
}
```

Usage example:

```qml
import QtQuick
import Hornero.PluginKit

UiCard {
    UiMetric { label: "CPU"; value: "42"; unit: "%" }
    UiProgress { value: 0.42 }
    UiButton {
        text: "Refresh"
        tooltipText: "Reload data"
        accessibleName: "Refresh"
        onClicked: Notifications.toast("Example", "Refreshed", "")
    }
    UiToggle { text: "Enabled"; accessibleName: "Enabled"; onToggled: () => print(checked) }
    UiState { kind: "empty"; message: "No data yet" }
}
```

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
  indication when `activeFocus` — use `Theme.focusRing` for the
  host focus colour and never rely on hover styling alone.
- **Focus restoration.** Opening a `UiPopover` moves focus into it;
  closing it (Escape, or activating a control inside) returns focus
  to the trigger. Never leave focus on a hidden or destroyed item.
- **Reduced motion and high contrast are inherited.** Kit
  transitions and the indeterminate `UiProgress` animation already
  honour the host settings; for your own animations use
  `Theme.motionDuration(ms)` (0 under reduced motion, scaled by
  the host animation speed otherwise) and gate looping motion on
  `!Theme.reducedMotion`. Theme colours already swap to the
  high-contrast palette; `Theme.highContrast` is exposed for
  emphasis decisions. Do not hardcode colours or durations.
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
main-axis cap is 240; dashboard cards report 380 wide and desktop
cards 300 wide, both with uncapped height.

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
  "schemaVersion": 1,
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
`"bar"` (rendered in the bar end group), or `"dashboard"`
(rendered as a card in the dashboard Extensions tab), or `"desktop"`
(rendered in a configurable slot on each display's background layer).
Unknown values are rejected by the validator and by the runtime host.

Use `processCommands` to disclose exact executable basenames and
`networkHosts` to disclose intended network hosts. These fields support code
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

## Manifest v2: multiple surfaces

`"schemaVersion": 2` keeps every version 1 field with the same meaning and
adds one optional field, `surfaces`: a map from surface name to that
surface's own entry point. The top-level `entrypoint`/`placement` pair stays
the package's **primary surface**, so a schemaVersion 1 manifest (or a v2
manifest without `surfaces`) loads identically to before: exactly one
effective surface, the placement, loading the top-level entrypoint,
enabled. Those are the documented defaults; nothing about v1 packages
changes.

```json
{
  "schemaVersion": 2,
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
| `desktop` | Widget in a named slot on each display's background layer. | Yes |
| `background` | Headless entry point (timers, toasts); only declare it where a headless component is justified. | Yes |
| `launcher` | Launcher/search action entry point. | No — validated declaration only; the launcher provider registry exists (shell#250 slice 1, [LAUNCHER.md](LAUNCHER.md)) but this entrypoint is not loaded yet, so plugin-defined providers are the follow-up slice (shell#222/#250), under the same trust wording as every other surface: in-process QML running as your user, unsandboxed. |
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
uncategorized card, exactly as before.

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
agree: unknown `schemaVersion` values are rejected (only `1` and `2` exist),
`surfaces` under schemaVersion 1 is rejected (so an older host can never
silently ignore it), and unknown top-level fields, unknown surface names,
unknown keys inside a surface, non-boolean `enabled`, empty `surfaces`, and
unsafe or unlisted surface entrypoints all fail with an actionable message.
Unknown extra fields are rejected, not ignored — the same policy v1 always
had. One cross-field rule cannot be expressed in JSON Schema (a redeclared
primary surface must reuse the top-level entrypoint); the schema documents
it, and the checker and runtime host enforce it.

Declaring a surface grants no privilege and changes nothing about the trust
boundary above: surfaces and `capabilities` alike are declarations —
review metadata, not enforcement, and not a permission grant. A surface
entrypoint gets exactly the same host Loader, PluginKit API, and
user-privilege execution as the primary entrypoint; there is no arbitrary
private-shell mutation path, and a `launcher` declaration in
particular causes no code to run at all until its host exists (a
`settings` declaration now runs only in its Control Center host,
above, and only for an enabled, installed plugin). Installing
or enabling a v2 package also requires a `horneroctl` build that accepts
schemaVersion 2; the shell-side contract here does not change the CLI's own
validation.

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

## Validate a package

```sh
python3 scripts/validate_plugin.py path/to/example-clock
```

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
