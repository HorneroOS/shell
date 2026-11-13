# Example Broken — QA fixture, do not ship enabled

**This is a deliberately broken QA fixture. It must never ship enabled
by default, never be enabled outside a QA/test run, and the missing
type in `Main.qml` must not be "fixed".**

It exists so `extensions/load-failure-isolation` (qa#81, shell#380)
can prove fault isolation honestly instead of passing vacuously:

- The manifest is fully valid: `scripts/validate_plugin.py` accepts
  this package, so it installs and is discovered like a healthy plugin.
  Its failure is a *runtime load* failure, not a manifest rejection.
- `Main.qml` references `BrokenFixtureMissingType`, a type that does
  not exist. The QML engine fails to create the component, the
  `PluginHost` `Loader` reports `Loader.Error`, and
  `services/Plugins.qml` marks only `example-broken` as `failed` with
  a bounded (50-event), secret-redacted diagnostic.
- A healthy neighbour (for example `example-clock`) keeps loading,
  and safe mode (`HORNERO_SAFE_MODE=1` or persisted safe mode) is
  unaffected: in safe mode no plugin manifest or QML is loaded at all.

Validate it (it must pass) from the repository root with:

```sh
python3 scripts/validate_plugin.py examples/plugins/example-broken
```

The manifest declares no process or network capability. Quickshell
code is not sandboxed; validation is a review aid, not a security
guarantee.
