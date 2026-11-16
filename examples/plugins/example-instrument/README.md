# Example Instrument

A desktop widget built from PluginKit 3 instruments: an oscilloscope
(`UiScope`) over the shared `Telemetry` CPU history plus memory and
temperature meter rows. It declares the `system` provider in
`capabilities.providers` and holds a `Subscription` lease while loaded.
An unavailable temperature sensor renders as unavailable, never as 0.

Validate it from the repository root with:

```sh
python3 scripts/validate_plugin.py examples/plugins/example-instrument
```

Quickshell code is not sandboxed; validation is a review aid, not a
security guarantee.
