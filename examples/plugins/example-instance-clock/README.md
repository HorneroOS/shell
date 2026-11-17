# Example Instance Clock

Demonstrates PluginKit 4 (`"pluginKit": 4`): a desktop widget that can be
placed more than once, with typed settings v2.

- `surfaces.desktop.instances: true` lets Control Center add extra
  instances; each has its own settings, position and size.
- The entrypoint declares `property string hostInstanceId: ""` and binds
  `Settings { pluginId: ...; instanceId: root.hostInstanceId }`; the validator
  refuses `instances: true` without both.
- Settings use `colour`, `text`, `step`/`unit`, `group`, `title` and
  `visibleWhen`; Control Center renders them with a live preview.

Validate it from the repository root with:

```sh
python3 scripts/validate_plugin.py examples/plugins/example-instance-clock
```

The manifest declares no process or network capability. Quickshell code is
not sandboxed; validation is a review aid, not a security guarantee.
