# Example Multi-Surface

This folder demonstrates the manifest v2 (`"schemaVersion": 2`) multi-surface
contract: one package exposes a bar indicator (the primary
`placement`/`entrypoint` pair) plus a dashboard card and a custom
Control Center settings surface (`Settings.qml`, shown in
Control Center › Extensions in its Custom settings tab, alongside the generated settings for the
typed `label` setting) declared in the `surfaces` map, each with its
own entrypoint file. See `docs/PLUGINS.md`, "Manifest v2: multiple
surfaces".

Validate it from the repository root with:

```sh
python3 scripts/validate_plugin.py examples/plugins/example-multi-surface
```

The manifest declares no process or network capability. Quickshell code is
not sandboxed; validation is a review aid, not a security guarantee.
