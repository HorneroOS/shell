# Hornero Shell extension contract

**Status: runtime slice 3 (headless loader + bar + dashboard placements).** The
Shell now discovers plugins that `horneroctl plugin list` reports as
enabled and installed, and instantiates each manifest entrypoint in
its own Loader (`modules/plugins/PluginHost.qml`, state in
`services/Plugins.qml`, inspect via `qs ipc call plugins status`,
re-discover with `qs ipc call plugins reload`). Lifecycle (install,
enable, disable, remove) is owned by `horneroctl plugin ...`;
enabling re-validates the installed payload. Background plugins
(the default) run headless under an invisible root. A manifest may
declare `"placement": "bar"`: the plugin is then rendered in the
bar's end group (`modules/plugins/PluginBarWidgets.qml`), still in
its own Loader, so one failing plugin cannot take the bar down.
With `"placement": "dashboard"` the entrypoint renders as a card
in the dashboard Extensions tab
(`modules/plugins/PluginDashboardCards.qml`), under the same
per-plugin Loader isolation. Desktop placement does not exist yet.
`Hornero.PluginKit` remains a reserved import surface; it is not yet
provided by the Shell package.

This contract gives community authors and maintainers a reviewable package
shape before a runtime loader exists. The manifest schema is
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

The checker is also covered by `tests/test_plugin_contract.py`. Adding this
contract does not alter shipped plugins or enable extension loading.
