# Example Desktop Note

This folder demonstrates the desktop placement of the Hornero Shell
extension contract: when this plugin is installed and enabled, the
Shell renders its entrypoint as a widget on the desktop background
layer (`modules/plugins/PluginDesktopWidgets.qml`).

Validate it from the repository root with:

```sh
python3 scripts/validate_plugin.py examples/plugins/example-desktop-note
```

The manifest declares no process or network capability. Quickshell
code is not sandboxed; validation is a review aid, not a security
guarantee.
