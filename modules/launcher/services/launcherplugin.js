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
//
// Optional multi-row form (additive): an entrypoint may instead (or as
// well) expose a readonly var property `results`, an array of
// { text: string, title?: string, subtitle?: string, glyph?: string }.
// When `results` is an array it wins over `result`, each entry becomes
// one row (at most MAX_ROWS) and activating a row copies that entry's
// `text`. An entrypoint exposing only `result` behaves exactly as before.

const MAX_ROWS = 24;
const MAX_LABEL = 200;
const MAX_TEXT = 16384;

function launcherPrefixFor(pluginId) {
    const id = typeof pluginId === "string" ? pluginId : "";
    return id.startsWith("hornero-") ? id.slice("hornero-".length) : id;
}

function launcherContractOk(item) {
    if (!item || typeof item !== "object")
        return false;
    if (!("query" in item))
        return false;
    if ("results" in item && Array.isArray(item.results))
        return true;
    if (!("result" in item))
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
        "icon": typeof icon === "string" && icon.length > 0 ? icon : "puzzle",
        "title": raw.text,
        "subtitle": typeof displayName === "string" && displayName.length > 0 ? displayName : pluginId,
        "payload": raw
    };
}

function _label(value, limit) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim().slice(0, limit) : "";
}

// Rows for one plugin: the multi-row `results` array when the entrypoint
// exposes one, else the single-row `result` mapping above. Malformed
// entries (not an object, no non-empty string `text`) are dropped, text is
// bounded, and labels are collapsed to one line so a multi-line clipboard
// entry cannot blow up the launcher layout.
function launcherRows(pluginId, displayName, icon, item) {
    if (!item || typeof item !== "object")
        return [];
    const fallbackIcon = typeof icon === "string" && icon.length > 0 ? icon : "puzzle";
    const fallbackSubtitle = typeof displayName === "string" && displayName.length > 0 ? displayName : pluginId;
    if (!Array.isArray(item.results)) {
        const row = launcherRow(pluginId, displayName, icon, item.result);
        return row ? [row] : [];
    }
    const rows = [];
    for (const entry of item.results) {
        if (rows.length >= MAX_ROWS)
            break;
        if (!entry || typeof entry !== "object" || typeof entry.text !== "string" || entry.text.length === 0)
            continue;
        const text = entry.text.slice(0, MAX_TEXT);
        const title = _label(entry.title, MAX_LABEL) || _label(text, MAX_LABEL);
        if (title === "")
            continue;
        rows.push({
            "providerId": pluginId,
            "section": pluginId,
            "icon": _label(entry.glyph, 48) || fallbackIcon,
            "title": title,
            "subtitle": _label(entry.subtitle, MAX_LABEL) || fallbackSubtitle,
            "payload": {
                "ok": true,
                "text": text
            }
        });
    }
    return rows;
}
