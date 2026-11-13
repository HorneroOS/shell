.pragma library

// Pure file-search logic for the launcher file provider
// (shell#250 slice 2). Bounded, privacy-aware, on-demand: no
// indexing daemon, no background crawling. The QML service
// (Files.qml) runs `find` only in response to a query; this
// module owns the bounds, exclusions, ranking and the find
// argv so tests can execute every rule under node and against
// a real fixture tree.

var MAX_RESULTS = 50;
var MAX_DEPTH = 4;
var HOME_MAX_DEPTH = 1;
var MIN_QUERY_LENGTH = 2;
var DEBOUNCE_MS = 250;

// Directory/file names that must never be searched or shown,
// even inside an allowed root. Hidden dot-components are
// excluded separately (any component starting with ".").
var SENSITIVE_NAMES = [".ssh", ".gnupg", ".aws", ".azure", ".gcp", ".kube", ".docker", "credentials", "secrets", "private"];
var SENSITIVE_FILE_PREFIXES = ["id_rsa", "id_dsa", "id_ecdsa", "id_ed25519"];
var SENSITIVE_FILE_SUFFIXES = [".pem", ".key", ".p12", ".pfx", ".kdbx"];

function normalizePath(path) {
    if (typeof path !== "string" || path.length === 0)
        return "";
    var parts = path.split("/");
    var out = [];
    for (var i = 0; i < parts.length; i++) {
        var part = parts[i];
        if (part === "" || part === ".")
            continue;
        if (part === "..") {
            out.pop();
            continue;
        }
        out.push(part);
    }
    return "/" + out.join("/");
}

function pathComponents(path) {
    var normalized = normalizePath(path);
    return normalized === "/" ? [] : normalized.substring(1).split("/");
}

function baseName(path) {
    var parts = pathComponents(path);
    return parts.length ? parts[parts.length - 1] : "";
}

function parentPath(path) {
    var parts = pathComponents(path);
    if (parts.length <= 1)
        return "/";
    return "/" + parts.slice(0, parts.length - 1).join("/");
}

function isHiddenPath(path) {
    var parts = pathComponents(path);
    for (var i = 0; i < parts.length; i++) {
        if (parts[i].length > 1 && parts[i].charAt(0) === ".")
            return true;
    }
    return false;
}

function isSensitivePath(path) {
    var parts = pathComponents(path);
    for (var i = 0; i < parts.length; i++) {
        var lower = parts[i].toLowerCase();
        if (SENSITIVE_NAMES.indexOf(lower) >= 0)
            return true;
        if (i === parts.length - 1) {
            for (var j = 0; j < SENSITIVE_FILE_PREFIXES.length; j++) {
                if (lower.indexOf(SENSITIVE_FILE_PREFIXES[j]) === 0)
                    return true;
            }
            for (var k = 0; k < SENSITIVE_FILE_SUFFIXES.length; k++) {
                if (lower.length > SENSITIVE_FILE_SUFFIXES[k].length && lower.substring(lower.length - SENSITIVE_FILE_SUFFIXES[k].length) === SENSITIVE_FILE_SUFFIXES[k])
                    return true;
            }
        }
    }
    return false;
}

// Roots may be strings or { path, maxDepth } objects.
function rootPath(root) {
    return typeof root === "string" ? root : (root && root.path) || "";
}

function rootMaxDepth(root) {
    if (root && typeof root === "object" && typeof root.maxDepth === "number")
        return root.maxDepth;
    return MAX_DEPTH;
}

// Lexical containment: path must be a root itself or below one.
// Normalizing ".." first means a crafted "../" segment cannot
// fake containment.
function containingRoot(path, roots) {
    var normalized = normalizePath(path);
    for (var i = 0; i < (roots || []).length; i++) {
        var root = normalizePath(rootPath(roots[i]));
        if (root && (normalized === root || normalized.indexOf(root + "/") === 0))
            return roots[i];
    }
    return null;
}

function isWithinRoots(path, roots) {
    return containingRoot(path, roots) !== null;
}

function relativeDepth(path, root) {
    return pathComponents(path).length - pathComponents(rootPath(root)).length;
}

function escapeGlob(text) {
    return String(text || "").replace(/([\\*?[\]])/g, "\\$1");
}

// The find argv (no shell, so the query can never be interpreted
// by one). Without -L, find never follows symlinked directories
// and -type f/-type d never match a symlink itself, so a symlink
// inside a root can neither be traversed nor returned. Hidden
// and sensitive names are pruned before descent. A missing or
// unreadable root only empties its own output; find still
// searches the remaining roots.
function buildFindArgs(roots, query, maxDepth) {
    var paths = [];
    for (var i = 0; i < (roots || []).length; i++) {
        var p = rootPath(roots[i]);
        if (p)
            paths.push(p);
    }
    var args = ["find"].concat(paths);
    args.push("-maxdepth", String(typeof maxDepth === "number" ? maxDepth : MAX_DEPTH));
    args.push("(", "-name", ".*");
    for (var s = 0; s < SENSITIVE_NAMES.length; s++) {
        if (SENSITIVE_NAMES[s].charAt(0) !== ".")
            args.push("-o", "-name", SENSITIVE_NAMES[s]);
    }
    args.push(")", "-prune", "-o");
    args.push("(", "-type", "f", "-o", "-type", "d", ")");
    args.push("-iname", "*" + escapeGlob(String(query || "").trim()) + "*");
    args.push("-printf", "%y\t%p\n");
    return args;
}

// Parses `-printf "%y\t%p\n"` output into { path, isDir } rows.
function parseFindOutput(text) {
    var entries = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        if (!line)
            continue;
        var tab = line.indexOf("\t");
        if (tab < 0)
            continue;
        var path = line.substring(tab + 1);
        if (!path)
            continue;
        entries.push({
            "path": path,
            "isDir": line.substring(0, tab) === "d"
        });
    }
    return entries;
}

function scoreEntry(entry, query) {
    var name = baseName(entry.path).toLowerCase();
    if (name === query)
        return 0;
    if (name.indexOf(query) === 0)
        return 1;
    if (name.indexOf(query) >= 0)
        return 2;
    if (parentPath(entry.path).toLowerCase().indexOf(query) >= 0)
        return 3;
    return 4;
}

// Filters (hidden, sensitive, outside-root, beyond-depth and
// symlink-escape via an optional resolved realPath), ranks and
// caps raw entries. Returns { path, name, parent, isDir } rows,
// best first.
function rankResults(entries, query, roots, maxResults) {
    var q = String(query || "").trim().toLowerCase();
    var cap = typeof maxResults === "number" && maxResults > 0 ? maxResults : MAX_RESULTS;
    var scored = [];
    var seen = {};
    for (var i = 0; i < (entries || []).length; i++) {
        var raw = entries[i];
        var entry = typeof raw === "string" ? { "path": raw, "isDir": false } : raw;
        if (!entry || typeof entry.path !== "string" || entry.path.length === 0)
            continue;
        var path = normalizePath(entry.path);
        if (seen[path])
            continue;
        var root = containingRoot(path, roots);
        if (!root)
            continue;
        var depth = relativeDepth(path, root);
        if (depth <= 0 || depth > rootMaxDepth(root))
            continue;
        if (isHiddenPath(path) || isSensitivePath(path))
            continue;
        // Symlink escape: when the caller resolved the entry, its
        // real target must stay inside an allowed root too.
        if (entry.realPath && !isWithinRoots(entry.realPath, roots))
            continue;
        if (entry.realPath && (isHiddenPath(entry.realPath) || isSensitivePath(entry.realPath)))
            continue;
        seen[path] = true;
        scored.push({
            "path": path,
            "name": baseName(path),
            "parent": parentPath(path),
            "isDir": entry.isDir === true,
            "_score": scoreEntry(entry, q),
            "_depth": depth
        });
    }
    scored.sort(function (a, b) {
        if (a._score !== b._score)
            return a._score - b._score;
        if (a._depth !== b._depth)
            return a._depth - b._depth;
        if (a.name.length !== b.name.length)
            return a.name.length - b.name.length;
        return a.path < b.path ? -1 : (a.path > b.path ? 1 : 0);
    });
    var out = [];
    for (var j = 0; j < scored.length && j < cap; j++) {
        out.push({
            "path": scored[j].path,
            "name": scored[j].name,
            "parent": scored[j].parent,
            "isDir": scored[j].isDir
        });
    }
    return out;
}

// XDG user dirs (env override, else ~/Name — the Paths.qml
// convention) at MAX_DEPTH, plus the home top level itself at
// HOME_MAX_DEPTH so top-level files are found without crawling
// the whole home tree.
function userRoots(home, env) {
    env = env || {};
    function dir(envName, fallback) {
        var value = env[envName];
        return typeof value === "string" && value.length > 0 ? value : home + "/" + fallback;
    }
    var roots = [
        { "path": dir("XDG_DOCUMENTS_DIR", "Documents"), "maxDepth": MAX_DEPTH },
        { "path": dir("XDG_DOWNLOAD_DIR", "Downloads"), "maxDepth": MAX_DEPTH },
        { "path": dir("XDG_DESKTOP_DIR", "Desktop"), "maxDepth": MAX_DEPTH },
        { "path": dir("XDG_PICTURES_DIR", "Pictures"), "maxDepth": MAX_DEPTH },
        { "path": dir("XDG_MUSIC_DIR", "Music"), "maxDepth": MAX_DEPTH },
        { "path": dir("XDG_VIDEOS_DIR", "Videos"), "maxDepth": MAX_DEPTH },
        { "path": home, "maxDepth": HOME_MAX_DEPTH }
    ];
    var out = [];
    var seen = {};
    for (var i = 0; i < roots.length; i++) {
        var normalized = normalizePath(roots[i].path);
        if (!normalized || seen[normalized])
            continue;
        seen[normalized] = true;
        out.push(roots[i]);
    }
    return out;
}
