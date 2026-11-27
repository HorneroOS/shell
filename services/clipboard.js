.pragma library

// Pure clipboard history helpers (HorneroOS/shell#737): MIME filtering,
// startup-burst suppression, bounded entry normalization, deduplication,
// and substring search. Executed both by services/Clipboard.qml and under
// Node.js in tests/test_clipboard_emoji_dock.py.

var MAX_ENTRIES = 50;
var MAX_TEXT_BYTES = 16384;
var INITIAL_BURST_MS = 600;

var SENSITIVE_MIME_PATTERNS = [
    "x-kde-passwordmanagerhint",
    "password",
    "keepass",
    "bitwarden",
    "1password"
];

var TEXT_MIME_EXACT = {
    "text": true,
    "string": true,
    "utf8_string": true,
    "application/json": true,
    "application/xml": true,
    "application/x-shellscript": true
};

function normalizeMimeList(mimeTypes) {
    if (typeof mimeTypes === "string")
        mimeTypes = mimeTypes.split(/\r?\n/);
    if (!Array.isArray(mimeTypes))
        return [];
    var out = [];
    for (var i = 0; i < mimeTypes.length; i++) {
        var m = String(mimeTypes[i] || "").trim().toLowerCase();
        if (m.length > 0)
            out.push(m);
    }
    return out;
}

function isSensitiveMime(mime) {
    var lower = String(mime || "").trim().toLowerCase();
    for (var i = 0; i < SENSITIVE_MIME_PATTERNS.length; i++) {
        if (lower.indexOf(SENSITIVE_MIME_PATTERNS[i]) !== -1)
            return true;
    }
    return false;
}

function isTextMime(mime) {
    var lower = String(mime || "").trim().toLowerCase();
    var semi = lower.indexOf(";");
    if (semi !== -1)
        lower = lower.slice(0, semi).trim();
    if (lower.indexOf("text/") === 0)
        return true;
    return TEXT_MIME_EXACT[lower] === true;
}

function shouldSkipMimeTypes(mimeTypes) {
    var list = normalizeMimeList(mimeTypes);
    if (list.length === 0)
        return true;
    var hasText = false;
    for (var i = 0; i < list.length; i++) {
        if (isSensitiveMime(list[i]))
            return true;
        if (isTextMime(list[i]))
            hasText = true;
    }
    return !hasText;
}

function isInitialBurst(nowMs, startedAtMs, burstMs) {
    var windowMs = typeof burstMs === "number" && burstMs >= 0 ? burstMs : INITIAL_BURST_MS;
    if (!(startedAtMs > 0))
        return false;
    return (nowMs - startedAtMs) < windowMs;
}

function primaryTextMime(mimeTypes) {
    var list = normalizeMimeList(mimeTypes);
    for (var i = 0; i < list.length; i++) {
        if (isTextMime(list[i]))
            return list[i];
    }
    return "text/plain";
}

function normalizeEntry(text, mime, nowMs, id) {
    if (typeof text !== "string")
        return null;
    if (text.trim().length === 0)
        return null;
    var bounded = text.length > MAX_TEXT_BYTES ? text.slice(0, MAX_TEXT_BYTES) : text;
    var oneLine = bounded.replace(/\s+/g, " ").trim();
    var preview = oneLine.length > 120 ? oneLine.slice(0, 119) + "…" : oneLine;
    var lines = bounded.split(/\r?\n/).length;
    return {
        id: id,
        text: bounded,
        preview: preview,
        mime: String(mime || "text/plain"),
        chars: bounded.length,
        lines: lines,
        timestamp: Number(nowMs) || 0
    };
}

function upsertEntry(entries, entry, maxEntries) {
    if (!entry || typeof entry.text !== "string")
        return Array.isArray(entries) ? entries.slice() : [];
    var cap = typeof maxEntries === "number" && maxEntries > 0 ? maxEntries : MAX_ENTRIES;
    var out = [entry];
    var list = Array.isArray(entries) ? entries : [];
    for (var i = 0; i < list.length && out.length < cap; i++) {
        if (list[i] && list[i].text !== entry.text)
            out.push(list[i]);
    }
    return out;
}

function filterEntries(entries, query) {
    var list = Array.isArray(entries) ? entries : [];
    var q = String(query || "").trim().toLowerCase();
    if (q.length === 0)
        return list.slice();
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var e = list[i];
        if (!e)
            continue;
        var hay = (String(e.preview || "") + "\n" + String(e.text || "")).toLowerCase();
        if (hay.indexOf(q) !== -1)
            out.push(e);
    }
    return out;
}

function formatMeta(entry) {
    if (!entry)
        return "";
    var chars = Number(entry.chars) || 0;
    var lines = Number(entry.lines) || 1;
    if (lines > 1)
        return lines + " lines · " + chars + " chars";
    return chars + " chars";
}
