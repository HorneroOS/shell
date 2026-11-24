pragma Singleton

import "launcherplugin.js" as LauncherPlugin
import qs.config
import qs.services
import Quickshell
import QtQuick

// Launcher provider registry (shell#250 slice 1).
//
// A provider declares { id, prefix, icon, section } plus
// query(text) -> ranked results and activate(result, list).
// Results are plain objects shaped
// { providerId, section, icon, title, subtitle, payload };
// a provider's query returns them already ranked (best first)
// and the registry preserves that order inside the section.
//
// Apps remain the default provider: when no registered prefix
// matches, AppList keeps its existing "apps" state and ordering
// (Apps.search / frecency) byte-identically. This registry only
// routes explicit `<actionPrefix><prefix> ` queries; it does
// not replace the AppList state machine or drawer lifecycle.
//
// Registration point: registerProvider(spec) below. Built-in
// providers (apps, calc, windows, files, ai) register at startup.
// Plugin-defined providers (surfaces.launcher) are hosted by
// modules/plugins/PluginLauncherHost.qml, which registers each
// hosted plugin here AFTER the built-ins (see builtinsRegistered)
// so built-in prefixes always win collisions. Plugin code never
// calls registerProvider itself. Hosting carries the same trust
// wording as every other plugin surface (in-process QML running
// as your user, unsandboxed — see docs/PLUGINS.md).
Singleton {
    id: root

    property var providers: []
    // True once the built-in providers below have registered.
    // The plugin launcher host waits for this before registering
    // any plugin provider, so a plugin can never shadow a
    // built-in route even if its Loader finishes first.
    property bool builtinsRegistered: false

    // Normalizes a provider's optional alias prefixes. Aliases
    // route to the same provider as prefix (for example Files
    // answers to both "file" and "files"); they never create a
    // second provider or widen what its query can do.
    function normalizedAliases(spec: var): var {
        if (!Array.isArray(spec.aliases))
            return null;
        const aliases = [];
        for (const alias of spec.aliases) {
            if (typeof alias !== "string" || alias.length === 0 || alias === spec.prefix)
                return null;
            if (!aliases.includes(alias))
                aliases.push(alias);
        }
        return aliases;
    }

    function routeTokens(provider: var): var {
        return [provider.prefix, ...(provider.aliases ?? [])];
    }

    // Registers a provider spec. Returns false (and keeps the
    // existing registry) for a malformed spec, a duplicate id
    // or a duplicate prefix/alias: first registration wins so a later
    // provider can never shadow a built-in route.
    function registerProvider(spec: var): bool {
        if (!spec || typeof spec.id !== "string" || spec.id.length === 0)
            return false;
        if (typeof spec.prefix !== "string")
            return false;
        if (typeof spec.query !== "function")
            return false;
        const aliases = spec.aliases === undefined ? [] : normalizedAliases(spec);
        if (aliases === null)
            return false;
        const tokens = [spec.prefix, ...aliases].filter(token => token.length > 0);
        for (const p of providers) {
            if (p.id === spec.id)
                return false;
            for (const token of tokens) {
                if (routeTokens(p).includes(token))
                    return false;
            }
        }
        providers = [...providers, {
                "id": spec.id,
                "prefix": spec.prefix,
                "aliases": aliases,
                "icon": typeof spec.icon === "string" ? spec.icon : "search",
                "section": typeof spec.section === "string" ? spec.section : spec.id,
                "bare": spec.bare === true,
                "query": spec.query,
                "activate": typeof spec.activate === "function" ? spec.activate : null
            }];
        return true;
    }

    // Removes a provider by id (plugin disable / safe mode /
    // Loader teardown). Returns false when no such provider is
    // registered. Built-ins are never unregistered by hosts.
    function unregisterProvider(id: string): bool {
        if (!providerById(id))
            return false;
        providers = providers.filter(p => p.id !== id);
        return true;
    }

    // Launcher prefix for a plugin id: the id minus a leading
    // "hornero-" (hornero-calculator -> calculator). Pure helper
    // in launcherplugin.js so tests can execute it.
    function launcherPrefixFor(pluginId: string): string {
        return LauncherPlugin.launcherPrefixFor(pluginId);
    }

    // Whether a loaded launcher entrypoint item satisfies the
    // established query/result contract (see launcherplugin.js).
    function launcherContractOk(item: var): bool {
        return LauncherPlugin.launcherContractOk(item);
    }

    // The single registry row for one plugin result, or null
    // when the result is not ok (no row is shown then).
    function launcherRow(pluginId: string, displayName: string, icon: string, raw: var): var {
        return LauncherPlugin.launcherRow(pluginId, displayName, icon, raw);
    }

    // Every registry row for one plugin entrypoint: its multi-row
    // `results` array when present, else the single `result` row.
    function launcherRows(pluginId: string, displayName: string, icon: string, item: var): var {
        return LauncherPlugin.launcherRows(pluginId, displayName, icon, item);
    }

    function providerById(id: string): var {
        for (const p of providers) {
            if (p.id === id)
                return p;
        }
        return null;
    }

    // The provider and exact route token an explicit-prefix query
    // uses, or null when no token matches (the caller then falls back
    // to the default apps provider). A token matches at end-of-string
    // as well as before a space, so `>file` enters the Files state
    // before the user types the separator. Longest token wins.
    function routeFor(text: string): var {
        const actionPrefix = Config.launcher.actionPrefix;
        if (!text.startsWith(actionPrefix))
            return null;
        let best = null;
        let bestToken = "";
        for (const p of providers) {
            for (const token of routeTokens(p)) {
                if (token.length === 0)
                    continue;
                const route = `${actionPrefix}${token}`;
                if ((text === route || text.startsWith(`${route} `)) && token.length > bestToken.length) {
                    best = p;
                    bestToken = token;
                }
            }
        }
        return best ? {
            "provider": best,
            "token": bestToken
        } : null;
    }

    function providerFor(text: string): var {
        const route = routeFor(text);
        return route ? route.provider : null;
    }

    // AppList state name for a query: the routed provider id,
    // or "" when the query belongs to the default/apps flow.
    function stateFor(text: string): string {
        const p = providerFor(text);
        return p ? p.id : "";
    }

    // The query text with the matched route (canonical prefix or
    // alias) stripped. A bare route has no query text yet.
    function queryText(text: string): string {
        const route = routeFor(text);
        if (!route)
            return text;
        const routeLength = Config.launcher.actionPrefix.length + route.token.length;
        return text.length > routeLength ? text.slice(routeLength + 1) : "";
    }

    function query(text: string): list<var> {
        const p = providerFor(text);
        if (!p)
            return [];
        return p.query(queryText(text));
    }

    function activate(result: var, list: var): void {
        if (!result)
            return;
        const p = providerById(result.providerId ?? "");
        if (p && p.activate)
            p.activate(result, list);
    }

    Component.onCompleted: {
        // Apps: the default provider. Its prefix is empty: it
        // owns every query no other prefix claims, and AppList
        // serves it through the historic Apps.search path so
        // ordering and frecency stay byte-identical.
        registerProvider({
            "id": "apps",
            "prefix": "",
            "icon": "apps",
            "section": "apps",
            "query": text => Apps.search(text).map(e => ({
                        "providerId": "apps",
                        "section": "apps",
                        "icon": "apps",
                        "title": e.name ?? "",
                        "subtitle": "",
                        "payload": e
                    }))
        });
        registerProvider({
            "id": "calc",
            "prefix": "calc",
            "icon": "function",
            "section": "calc",
            "query": text => {
                const r = Calc.evaluate(text);
                return [{
                        "providerId": "calc",
                        "section": "calc",
                        "icon": "function",
                        "title": text,
                        "subtitle": r.ok ? r.text : "",
                        "payload": r
                    }];
            }
            // No registry activate for calc: the CalcItem
            // delegate owns activation (Enter copies the
            // result), as it did before the registry existed.
        });
        registerProvider({
            "id": "win",
            "prefix": "win",
            "icon": "app-window",
            "section": "win",
            "query": text => Windows.query(text).map(w => ({
                        "providerId": "win",
                        "section": "win",
                        "icon": "app-window",
                        "title": w.title,
                        "subtitle": w.appClass,
                        "payload": w
                    })),
            "activate": (result, list) => {
                Windows.activate(result.payload);
                if (list)
                    list.visibilities.launcher = false;
            }
        });
        registerProvider({
            "id": "file",
            "prefix": "file",
            "aliases": ["files"],
            "icon": "folder-open",
            "section": "Files",
            // Async provider: requestSearch is debounced and
            // idempotent per query text; this returns the current
            // ranked snapshot and re-evaluates when Files.results
            // changes. Activation opens via xdg-open, the shell's
            // existing open-path convention (FileItem before the
            // registry did exactly this).
            "query": text => {
                Files.requestSearch(text);
                return Files.results.map(e => ({
                            "providerId": "file",
                            "section": "Files",
                            "icon": e.isDir ? "folder-open" : "file-text",
                            "title": e.name,
                            "subtitle": e.parent,
                            "payload": e
                        }));
            },
            "activate": (result, list) => {
                Files.activate(result);
                if (list)
                    list.visibilities.launcher = false;
            }
        });
        registerProvider({
            "id": "ai",
            "prefix": "ai",
            "icon": "feather",
            "section": "ai",
            // Inline ask (shell#250 slice 3): one row for the
            // question; the AiItem delegate renders the streamed
            // answer from the InlineAsk singleton, so this query
            // only snapshots the current question. Activation
            // toggles ask/stop and never closes the launcher --
            // the answer arrives in place.
            "query": text => [{
                        "providerId": "ai",
                        "section": "ai",
                        "icon": "feather",
                        "title": text,
                        "subtitle": InlineAsk.busy && InlineAsk.owner === "launcher" ? qsTr("Javi is thinking…") : "",
                        "payload": {
                            "question": text
                        }
                    }],
            "activate": (result, list) => {
                if (InlineAsk.busy && InlineAsk.owner === "launcher")
                    InlineAsk.cancel("launcher");
                else
                    InlineAsk.ask((result.payload?.question ?? result.title ?? "").toString(), "launcher");
            }
        });
        root.builtinsRegistered = true;
    }
}
