.pragma library

// Pure helpers for plugin-defined launcher providers (shell#250
// follow-up). Kept dependency-free so tests can execute them under
// node, exactly like calcparser.js / windowfilter.js.
//
// Established plugin contract (shipped by the HorneroOS/plugins
// utility packages, e.g. hornero-calculator/Launcher.qml): the
// launcher entrypoint root Item exposes a settable string property
// `query` and a readonly var property `result` shaped
// { ok: bool, text: string }. The host sets query, reads result.

function launcherPrefixFor(pluginId) {
    const id = typeof pluginId === "string" ? pluginId : "";
    return id.startsWith("hornero-") ? id.slice("hornero-".length) : id;
}

function launcherContractOk(item) {
    if (!item || typeof item !== "object")
        return false;
    if (!("query" in item) || !("result" in item))
        return false;
    const result = item.result;
    return !!result && typeof result === "object" && typeof result.ok === "boolean" && typeof result.text === "string";
}

// Map one plugin result to the single registry row for it, or null
// when there is no row. Not-ok results produce no row (documented
// in docs/LAUNCHER.md): the plugin's not-ok text is a placeholder
// such as "Error"/"Enter a value", not a result, and the registry
// has no disabled-row concept to carry it.
function launcherRow(pluginId, displayName, icon, raw) {
    if (!raw || typeof raw !== "object" || raw.ok !== true || typeof raw.text !== "string" || raw.text.length === 0)
        return null;
    return {
        "providerId": pluginId,
        "section": pluginId,
        "icon": typeof icon === "string" && icon.length > 0 ? icon : "extension",
        "title": raw.text,
        "subtitle": typeof displayName === "string" && displayName.length > 0 ? displayName : pluginId,
        "payload": raw
    };
}
