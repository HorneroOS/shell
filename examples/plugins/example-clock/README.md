# Example Clock

This folder demonstrates the manifest, file inventory, import surface, and
static validation contract for a future Hornero Shell extension. The current
Shell has no third-party plugin loader, so this example does not run inside
Hornero Shell.

Validate it from the repository root with:

```sh
python3 scripts/validate_plugin.py examples/plugins/example-clock
```

The manifest declares no process or network capability. Quickshell code is
not sandboxed; validation is a review aid, not a security guarantee.
