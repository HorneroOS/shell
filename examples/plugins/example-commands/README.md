# Example Commands

Demonstrates the PluginKit 4 `commands` contribution (RFC 0003 section 4.2).

- `contributes.commands` declares each command (id, title, glyph, keywords);
  the shell lists them without running this package.
- `surfaces.commands` is the entrypoint implementing
  `function run(commandId: string, args: string): string`.
- Reachable from the launcher (`>do hello`), IPC
  (`qs ipc call plugincommands run example-commands greet Ada`) and any key
  binding that runs that command. The shell writes no key binding itself.

Validate it from the repository root with:

```sh
python3 scripts/validate_plugin.py examples/plugins/example-commands
```

The manifest declares no process or network capability. Quickshell code is
not sandboxed; validation is a review aid, not a security guarantee.
