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
the shell or neighbouring extensions. Desktop widgets use nine named slots
per display. Their locations persist in the user's shell config, reflow when
resolution changes, and remain saved while a display is disconnected. A new
or unrecognized display and malformed slot data fall back to `bottom-right`.
Users select a widget's vertical and horizontal slot in Control Center.

The package installs the stable `Hornero.PluginKit` QML module. It exposes
`Settings`, `Theme`, `Notifications`, `Desktop`, `System`, `Network`,
`Media`, `Weather`, `Time`, `Power`, and `Audio` without requiring plugins
to import Shell internals:

- `Settings { pluginId: "example-clock" }` reads and writes keys declared by
  the selected manifest ID. Defaults and types come from
  `capabilities.settings`; user values are stored under that ID in
  `$XDG_CONFIG_HOME/hornero/shell.json`. The ID is a namespace selector, not
  proof of the caller's identity or an access boundary between extensions.
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
| `UiToggle` | Boolean switch | `value` (two-way synced with `checked`), `text`, `accessibleName`; inherits `toggled()` from `Switch`/`AbstractButton` (no argument — read `checked`/`value` in `onToggled`) |
| `UiSlider` | Range input | `from`, `to`, `value`, `accessibleName` (defaults to `Slider`) |
| `UiMetric` | Labelled metric | `label`, `value`, optional `unit` |
| `UiChip` | Small label chip | `text`, `tone`: `neutral` / `primary` / `error` |
| `UiProgress` | Progress bar | `value` (0..1), `indeterminate`, `animated` (default `false`) |
| `UiState` | State placeholder | `kind`: `loading` / `error` / `empty`, `message` |

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

The manifest schema is
[`schemas/plugin-manifest.schema.json`](../schemas/plugin-manifest.schema.json)
and the local checker is `scripts/validate_plugin.py`.

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
