pragma Singleton

import "launcherplugin.js" as LauncherPlugin
import qs.config
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
// providers (apps, calc, windows, files) register at startup.
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

    // Registers a provider spec. Returns false (and keeps the
    // existing registry) for a malformed spec, a duplicate id
    // or a duplicate prefix: first registration wins so a later
    // provider can never shadow a built-in route.
    function registerProvider(spec: var): bool {
        if (!spec || typeof spec.id !== "string" || spec.id.length === 0)
            return false;
        if (typeof spec.prefix !== "string")
            return false;
        if (typeof spec.query !== "function")
            return false;
        for (const p of providers) {
            if (p.id === spec.id || (spec.prefix.length > 0 && p.prefix === spec.prefix))
                return false;
        }
        providers = [...providers, {
                "id": spec.id,
                "prefix": spec.prefix,
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

    function providerById(id: string): var {
        for (const p of providers) {
            if (p.id === id)
                return p;
        }
        return null;
    }

    // The provider an explicit-prefix query routes to, or null
    // when no prefix matches (the caller then falls back to the
    // default apps provider). Longest prefix wins.
    function providerFor(text: string): var {
        const actionPrefix = Config.launcher.actionPrefix;
        if (!text.startsWith(actionPrefix))
            return null;
        let best = null;
        for (const p of providers) {
            if (p.prefix.length === 0)
                continue;
            if (text.startsWith(`${actionPrefix}${p.prefix} `) && (!best || p.prefix.length > best.prefix.length))
                best = p;
        }
        return best;
    }

    // AppList state name for a query: the routed provider id,
    // or "" when the query belongs to the default/apps flow.
    function stateFor(text: string): string {
        const p = providerFor(text);
        return p ? p.id : "";
    }

    // The query text with `<actionPrefix><prefix> ` stripped.
    function queryText(text: string): string {
        const p = providerFor(text);
        if (!p)
            return text;
        return text.slice(Config.launcher.actionPrefix.length + p.prefix.length + 1);
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
            "icon": "web_asset",
            "section": "win",
            "query": text => Windows.query(text).map(w => ({
                        "providerId": "win",
                        "section": "win",
                        "icon": "web_asset",
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
            "icon": "folder_open",
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
                            "icon": e.isDir ? "folder_open" : "description",
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
        root.builtinsRegistered = true;
    }
}
