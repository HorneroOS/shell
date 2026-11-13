# Example Launcher Broken (QA fixture)

QA fixture — must never ship enabled. A valid manifest v2 package whose
`surfaces.launcher` entrypoint (`Launcher.qml`) deliberately fails to load
at runtime (unresolved type), so `PluginLauncherHost` fault isolation can be
proven: only this plugin is marked failed, the launcher and other providers
keep working. Its background entrypoint is healthy.

Validate it from the repository root with:

```sh
python3 scripts/validate_plugin.py examples/plugins/example-launcher-broken
```

Quickshell code is not sandboxed; validation is a review aid, not a
security guarantee.
