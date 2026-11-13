# Launcher providers

The launcher is a federated command center built on one provider
registry (`modules/launcher/services/Providers.qml`, shell#250).
Providers plug into the existing launcher: the `AppList` state
machine and the drawer lifecycle are unchanged, and no provider
replaces them.

## Registry contract

A provider declares:

| Field | Meaning |
| --- | --- |
| `id` | Stable state/section name (for example `calc`, `win`). |
| `prefix` | Explicit route under `Config.launcher.actionPrefix` (default `>`): `>calc …`, `>win …`. Empty for the default provider. |
| `icon` | Material icon name for the section. |
| `section` | Section its results belong to. |
| `query(text)` | Returns ranked results, best first. The registry preserves that order inside the section. |
| `activate(result, list)` | Optional activation callback. Delegates may own activation instead (the calculator row does). |

A result is a plain object shaped
`{ providerId, section, icon, title, subtitle, payload }`.
Registration goes through `Providers.registerProvider(spec)`;
a malformed spec, a duplicate `id` or a duplicate `prefix` is
rejected (first registration wins, so nothing can shadow a
built-in route).

Apps remain the default provider (registered with an empty
prefix). When no registered prefix matches, `AppList` keeps its
existing `apps` state and serves `Apps.search` exactly as
before — same ordering, same frecency, byte-identical
behaviour. Only an explicit prefix query (`>calc …`, `>win …`) leaves the apps
flow. Arrow keys move across the merged result list, Enter
activates the current row and the Escape cascade
(`Drawers.dismissTopmost`) is unchanged, for every provider.

## Built-in providers (slice 1)

| Provider | Route | Behaviour |
| --- | --- | --- |
| Apps | *(default)* | Existing app search and frecency ordering. |
| Calculator | `>calc <expr>` | Safe arithmetic with the shell's own parser (below). Enter/click copies the result and closes the launcher, the historic convention for this row. |
| Windows | `>win <query>` | Lists open windows (title, app class, workspace) from `Hypr.toplevels` — the same toplevel source the bar uses — filtered case-insensitively on title/class in compositor order. Activation focuses through the shell's existing path, `Hypr.dispatch("focuswindow address:0x…")`; no new IPC. Hyprland-only today; Niri rows arrive with its window read model. |

File search (`>file`) and inline AI (`>ai`) predate the registry
and keep their existing states in this slice; they migrate onto
the registry incrementally, with no behaviour change intended.

## Calculator

Evaluation is the shell's own hand-written parser
(`modules/launcher/services/calcparser.js`, wrapped by the
`Calc` singleton): a tokenizer plus recursive descent for
`+ - * / %`, parentheses, decimals and unary `+`/`-`. Its
semantics mirror the hornero-calculator plugin; the plugin's
QML is not copied. There is no `eval`, no `Function` and no
process involved in evaluation. Malformed input, trailing
garbage, division or modulo by zero and non-finite results
show `Error` and copy nothing. Units, functions and currency
(the old libqalculate vocabulary) are out of scope for this
provider.

**Bare expressions are not routed.** Typing `2+3` without the
`>calc` prefix stays an app search. App names legitimately
contain digits and operator characters, so a bare-expression
section could shadow the app result the user wants; the
prefix is the unambiguous, discoverable route (the Calculator
action autocompletes it). `Calc.looksLikeExpression` — whole
text parses *and* contains an operator — is the gate any
future bare-calc section must pass before it may sit beside,
never above, app results.

## Plugin-defined providers (follow-up slice)

Plugin packages can already declare a `surfaces.launcher`
entry point in a manifest v2, but **no host loads it in this
slice**: plugin code cannot call `registerProvider` yet, and
the declaration stays validated-but-unloaded (see
`modules/plugins/PluginHost.qml` and the surface table in
[PLUGINS.md](PLUGINS.md)). Hosting plugin providers through
PluginKit, on this same registry contract, is the follow-up
slice. When it lands it carries the same trust wording as
every other plugin surface: in-process QML running as your
user, unsandboxed — exactly the same trust as the plugin's
other surfaces, not a permission boundary. Until then, do not
treat a `surfaces.launcher` declaration as a working provider.
