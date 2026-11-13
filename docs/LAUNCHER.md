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

## Plugin-defined providers

Plugin packages declaring a `surfaces.launcher` entry point in a
manifest v2 are now hosted by
`modules/plugins/PluginLauncherHost.qml` (wired in `shell.qml`).
Plugin code never calls `registerProvider` itself; the host does
it on the plugin's behalf, on this same registry contract.

**Entrypoint contract (established, not invented here).** The
entrypoint root `Item` exposes a settable string property
`query` and a readonly var property `result` shaped
`{ ok: bool, text: string }` — the contract already shipped by
the HorneroOS/plugins utility packages (for example
`hornero-calculator/Launcher.qml`). The host sets `query` to the
text after the route prefix and reads `result`. An entrypoint
missing that contract (or whose `result` is not
`{ok: bool, text: string}`) is skipped with a
`launcher-contract-missing` diagnostic and never registered; it
does not fail the plugin's other surfaces.

**Registration.** Each hosted plugin registers with
`id` = plugin id, `prefix` = plugin id minus a leading
`hornero-` (`hornero-calculator` → `calculator`,
`hornero-unit-converter` → `unit-converter`), `icon` = the
plugin entry's `icon` string when one is available, otherwise
the generic `extension` icon, and `section` = plugin id.
Registration happens only after the built-in providers have
registered (`Providers.builtinsRegistered`), and the registry
rejects duplicate ids/prefixes, so a built-in prefix always
wins a collision; a rejected registration is logged as
`launcher-registration-rejected` and never routes. Disabling a
plugin (or safe mode) unregisters it and unloads its Loader.

**Query and activation.** On query the host sets
`item.query = queryText` and reads `item.result`. An `ok`
result becomes a single row
`{title: result.text, subtitle: plugin display name, providerId: plugin id}`.
A not-ok result produces **no row**: its text is a placeholder
such as `Error`/`Enter a value`, not a result, and the registry
has no disabled-row concept — this is deliberately unlike the
built-in calc row, which always shows one row for its own
expression. There is no plugin activation hook in the contract,
so activation copies `result.text` via `wl-copy`
(`Quickshell.execDetached(["wl-copy", …])`), exactly the
built-in calc provider's convention, and closes the launcher.

**Fault isolation.** Each plugin loads in its own hidden,
asynchronous Loader. `Loader.Error` marks only that plugin
failed through `Plugins.markFailed`; one broken launcher plugin
never breaks the launcher or other providers (fixture:
`examples/plugins/example-launcher-broken`).

Plugin providers carry the same trust wording as every other
plugin surface: in-process QML running as your user,
unsandboxed — exactly the same trust as the plugin's other
surfaces, not a permission boundary.
