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
`Settings`, `Theme`, `Notifications`, and `Desktop` without requiring plugins
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
