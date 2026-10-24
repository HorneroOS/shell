# Hornero Shell extension contract

**Status: runtime slice 3 (headless loader + bar + dashboard placements).** The
Shell now discovers plugins that `horneroctl plugin list` reports as
enabled and installed, and instantiates each manifest entrypoint in
its own Loader (`modules/plugins/PluginHost.qml`, state in
`services/Plugins.qml`, inspect via `qs ipc call plugins status`,
re-discover with `qs ipc call plugins reload`). Lifecycle (install,
enable, disable, remove) is owned by `horneroctl plugin ...`;
enabling re-validates the installed payload. The Control Center
Extensions pane can enable/disable by invoking those exact
`horneroctl` commands (never writing receipts itself); enable
requires an inline confirmation there, mirroring the CLI `--yes`
gate, while install/remove stay CLI-only. Background plugins
(the default) run headless under an invisible root. A manifest may
declare `"placement": "bar"`: the plugin is then rendered in the
bar's end group (`modules/plugins/PluginBarWidgets.qml`), still in
its own Loader, so one failing plugin cannot take the bar down.
With `"placement": "dashboard"` the entrypoint renders as a card
in the dashboard Extensions tab
(`modules/plugins/PluginDashboardCards.qml`), under the same
per-plugin Loader isolation. With `"placement": "desktop"` the
entrypoint renders as a widget stacked bottom-right on the
desktop background layer, per screen
(`modules/plugins/PluginDesktopWidgets.qml`); widget positioning
and persistence are not configurable yet.
`Hornero.PluginKit` remains a reserved import surface; it is not yet
provided by the Shell package.

This contract gives community authors and maintainers a reviewable package
shape for the runtime loader. The manifest schema is
[`schemas/plugin-manifest.schema.json`](../schemas/plugin-manifest.schema.json)
and the local checker is `scripts/validate_plugin.py`.

## Trust boundary

Quickshell QML executes with the logged-in user's permissions. Hornero Shell
does not sandbox QML, and a manifest declaration cannot restrict filesystem,
process, or network access at runtime. The validator catches a conservative
set of malformed packages and suspicious source patterns; passing it is not a
security certification. Review source before running a community extension.
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
(rendered as a card in the dashboard Extensions tab). Unknown
values are rejected by the validator and by the runtime host.

Use `processCommands` to disclose exact executable basenames and
`networkHosts` to disclose intended network hosts. These fields support code
review only; they are not an operating-system permission grant. Settings are
typed metadata with explicit defaults. A future host must own persistence and
expose settings through a stable API rather than letting extensions rewrite
Shell configuration files.

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
public modules plus the future `Hornero.PluginKit` API. Imports from Hornero's
internal implementation are not stable and are rejected. The checker also
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
