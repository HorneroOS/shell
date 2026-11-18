import Quickshell.Io

// Per-layout overrides (docs/LAYOUTS.md, "My tweaks for a layout").
// { "<layout id>": { "<dotted config key>": value } } using the keys listed in
// services/layouts.js KEYS. Applying a layout preset rewrites the bars and
// sizes; the overrides saved for that layout are laid back on top afterwards.
// Empty by default: a layout ships exactly its preset until you save tweaks.
JsonObject {
    property var overrides: ({})
}
