.pragma library

// Structural helpers for CompanionStore's voice/habitat/radio preference
// document. Pure and dependency-free so tests run them under node; each
// section's values are validated by its own module (javivoice.js,
// habitat.js, radio.js), this file only guards the document's shape.

// Path segments that would reach an object's prototype instead of one
// of its own keys. A dotted path containing any of them is rejected.
const UNSAFE_SEGMENTS = ["__proto__", "constructor", "prototype"];

function isPlainObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

// The value when it is a plain object, else {} (null, arrays, strings,
// numbers from a hand-edited or corrupt document all read as empty).
function asObject(value) {
    return isPlainObject(value) ? value : {};
}

// JSON text to a plain object; "" / invalid JSON / non-object JSON -> {}.
function parseObject(text) {
    if (typeof text !== "string" || text === "")
        return {};
    try {
        return asObject(JSON.parse(text));
    } catch (e) {
        return {};
    }
}

// Dotted path split into segments, or null when the path is empty, has
// an empty segment or names a prototype key.
function pathSegments(path) {
    if (typeof path !== "string" || path === "")
        return null;
    const parts = path.split(".");
    for (const part of parts) {
        if (part === "" || UNSAFE_SEGMENTS.indexOf(part) >= 0)
            return null;
    }
    return parts;
}

// Set target[a][b]...[last] = value along an existing chain of own,
// plain-object keys. Returns false (and leaves target untouched) when the
// path is unsafe or does not lead to an existing object.
function setPath(target, path, value) {
    const parts = pathSegments(path);
    if (parts === null || !isPlainObject(target))
        return false;
    let node = target;
    for (let i = 0; i < parts.length - 1; i++) {
        if (!Object.prototype.hasOwnProperty.call(node, parts[i]))
            return false;
        node = node[parts[i]];
        if (!isPlainObject(node))
            return false;
    }
    node[parts[parts.length - 1]] = value;
    return true;
}
