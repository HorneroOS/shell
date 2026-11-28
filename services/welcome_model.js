.pragma library

// Hornero Welcome v2 pure state model, v1->v2 migration, typed deep-link
// action validator, and unified discovery search.
// Tested headlessly under node in tests/test_welcome_redesign.py and
// tests/test_welcome_state.py.

var SCHEMA_VERSION = 2;
var DEFAULT_REVISION = "p2";
var CURRENT_RELEASE_VERSION = "1.6.0";

var MODES = ["first-flight", "explore", "whats-new"];

var FIRST_FLIGHT_SCENES = [
    "arrival",
    "personalize",
    "workstation",
    "companion",
    "practice",
    "extensions",
    "showcase",
    "trust",
    "ready"
];

var CORE_SCENES = [
    "arrival",
    "personalize",
    "workstation",
    "companion",
    "ready"
];

var TUTORIAL_IDS = [
    "launcher",
    "dashboard",
    "workspace",
    "settings"
];

var INTEREST_IDS = [
    "creative",
    "dev",
    "gaming"
];

var LEGACY_PAGE_MAP = {
    "start": { mode: "first-flight", scene: "arrival", view: "" },
    "personalize": { mode: "first-flight", scene: "personalize", view: "" },
    "apps": { mode: "first-flight", scene: "workstation", view: "" },
    "javi": { mode: "first-flight", scene: "companion", view: "" },
    "navigate": { mode: "first-flight", scene: "practice", view: "" },
    "shell": { mode: "first-flight", scene: "practice", view: "" },
    "workspaces": { mode: "first-flight", scene: "practice", view: "" },
    "tools": { mode: "first-flight", scene: "showcase", view: "" },
    "system": { mode: "first-flight", scene: "trust", view: "" },
    "settings": { mode: "explore", scene: "", view: "features", category: "settings" },
    "learn": { mode: "whats-new", scene: "", view: "" },
    "shortcuts": { mode: "explore", scene: "", view: "shortcuts" }
};

var ALLOWED_DRAWERS = ["launcher", "dashboard", "utilities", "session", "layoutPicker"];
var ALLOWED_ACTIONS = ["openTerminal", "openKeybindsOverlay", "openApps", "refreshDiagnostics"];

function defaultState() {
    return {
        schemaVersion: SCHEMA_VERSION,
        showOnLogin: true,
        firstRunCompleted: false,
        firstRunCompletedAt: "",
        lastSeenReleaseVersion: "",
        contentRevision: DEFAULT_REVISION,
        lastSeenContentRevision: "",
        lastVisitedScene: "arrival",
        completedTutorials: [],
        selectedInterests: [],
        mascotEnabled: true,
        firstOpenedAt: "",
        lastOpenedAt: ""
    };
}

function _uniqueValidIds(arr, allowlist) {
    if (!Array.isArray(arr))
        return [];
    var out = [];
    var seen = {};
    for (var i = 0; i < arr.length; i++) {
        var v = String(arr[i] || "").trim().toLowerCase();
        if (!v || seen[v])
            continue;
        if (allowlist && allowlist.indexOf(v) === -1)
            continue;
        seen[v] = true;
        out.push(v);
    }
    return out;
}

function _validScene(scene) {
    var s = String(scene || "").trim().toLowerCase();
    return FIRST_FLIGHT_SCENES.indexOf(s) !== -1 ? s : "arrival";
}

// Tolerant parser + v1->v2 migration.
// Existing v1 users who opted out (showOnLogin=false) or already saw Welcome
// (lastSeenContentRevision or firstOpenedAt set) migrate with
// firstRunCompleted=true so they are NEVER forced back through First Flight.
function parseState(rawText) {
    var base = defaultState();
    if (typeof rawText !== "string" || rawText.trim() === "")
        return base;
    var o = null;
    try {
        o = JSON.parse(rawText);
    } catch (e) {
        return base;
    }
    if (!o || typeof o !== "object" || Array.isArray(o))
        return base;

    if (o.schemaVersion === 1) {
        if (typeof o.showOnLogin !== "boolean")
            return base;
        var rev = typeof o.contentRevision === "string" ? o.contentRevision : "p1";
        var seenRev = typeof o.lastSeenContentRevision === "string" ? o.lastSeenContentRevision : "";
        var firstAt = typeof o.firstOpenedAt === "string" ? o.firstOpenedAt : "";
        var lastAt = typeof o.lastOpenedAt === "string" ? o.lastOpenedAt : "";
        var alreadyUsed = (o.showOnLogin === false) || (seenRev !== "") || (firstAt !== "");
        return {
            schemaVersion: SCHEMA_VERSION,
            showOnLogin: o.showOnLogin,
            firstRunCompleted: alreadyUsed,
            firstRunCompletedAt: alreadyUsed ? (firstAt || "") : "",
            lastSeenReleaseVersion: "",
            contentRevision: rev,
            lastSeenContentRevision: seenRev,
            lastVisitedScene: "arrival",
            completedTutorials: [],
            selectedInterests: [],
            mascotEnabled: true,
            firstOpenedAt: firstAt,
            lastOpenedAt: lastAt
        };
    }

    if (o.schemaVersion !== SCHEMA_VERSION)
        return base;

    var show = typeof o.showOnLogin === "boolean" ? o.showOnLogin : true;
    var completed = typeof o.firstRunCompleted === "boolean"
        ? o.firstRunCompleted
        : (show === false);
    return {
        schemaVersion: SCHEMA_VERSION,
        showOnLogin: show,
        firstRunCompleted: completed,
        firstRunCompletedAt: typeof o.firstRunCompletedAt === "string" ? o.firstRunCompletedAt : "",
        lastSeenReleaseVersion: typeof o.lastSeenReleaseVersion === "string" ? o.lastSeenReleaseVersion : "",
        contentRevision: typeof o.contentRevision === "string" ? o.contentRevision : DEFAULT_REVISION,
        lastSeenContentRevision: typeof o.lastSeenContentRevision === "string" ? o.lastSeenContentRevision : "",
        lastVisitedScene: _validScene(o.lastVisitedScene),
        completedTutorials: _uniqueValidIds(o.completedTutorials, TUTORIAL_IDS),
        selectedInterests: _uniqueValidIds(o.selectedInterests, INTEREST_IDS),
        mascotEnabled: typeof o.mascotEnabled === "boolean" ? o.mascotEnabled : true,
        firstOpenedAt: typeof o.firstOpenedAt === "string" ? o.firstOpenedAt : "",
        lastOpenedAt: typeof o.lastOpenedAt === "string" ? o.lastOpenedAt : ""
    };
}

function mergeProgress(baseState, progressRaw) {
    var st = baseState ? Object.assign({}, baseState) : defaultState();
    if (typeof progressRaw !== "string" || progressRaw.trim() === "")
        return st;
    var p = null;
    try {
        p = JSON.parse(progressRaw);
    } catch (e) {
        return st;
    }
    if (!p || typeof p !== "object" || Array.isArray(p) || p.schemaVersion !== SCHEMA_VERSION)
        return st;
    if (typeof p.firstRunCompleted === "boolean")
        st.firstRunCompleted = st.firstRunCompleted || p.firstRunCompleted;
    if (typeof p.firstRunCompletedAt === "string" && p.firstRunCompletedAt !== "")
        st.firstRunCompletedAt = p.firstRunCompletedAt;
    if (typeof p.lastSeenReleaseVersion === "string" && p.lastSeenReleaseVersion !== "")
        st.lastSeenReleaseVersion = p.lastSeenReleaseVersion;
    if (typeof p.lastVisitedScene === "string")
        st.lastVisitedScene = _validScene(p.lastVisitedScene);
    if (Array.isArray(p.completedTutorials))
        st.completedTutorials = _uniqueValidIds(p.completedTutorials, TUTORIAL_IDS);
    if (Array.isArray(p.selectedInterests))
        st.selectedInterests = _uniqueValidIds(p.selectedInterests, INTEREST_IDS);
    if (typeof p.mascotEnabled === "boolean")
        st.mascotEnabled = p.mascotEnabled;
    return st;
}

function serializeProgress(state) {
    var st = state || defaultState();
    return JSON.stringify({
        schemaVersion: SCHEMA_VERSION,
        firstRunCompleted: st.firstRunCompleted === true,
        firstRunCompletedAt: String(st.firstRunCompletedAt || ""),
        lastSeenReleaseVersion: String(st.lastSeenReleaseVersion || ""),
        lastVisitedScene: _validScene(st.lastVisitedScene),
        completedTutorials: _uniqueValidIds(st.completedTutorials, TUTORIAL_IDS),
        selectedInterests: _uniqueValidIds(st.selectedInterests, INTEREST_IDS),
        mascotEnabled: st.mascotEnabled !== false
    }, null, 2);
}

function isValidTarget(target) {
    var t = String(target || "").trim().toLowerCase();
    if (t === "")
        return false;
    return MODES.indexOf(t) !== -1
        || FIRST_FLIGHT_SCENES.indexOf(t) !== -1
        || Object.prototype.hasOwnProperty.call(LEGACY_PAGE_MAP, t);
}

function resolveOpenTarget(rawTarget, state) {
    var t = String(rawTarget || "").trim().toLowerCase();
    if (t === "") {
        if (state && state.firstRunCompleted === true)
            return { mode: "explore", scene: "arrival", view: "features", category: "", unknown: false };
        return { mode: "first-flight", scene: "arrival", view: "", category: "", unknown: false };
    }
    if (MODES.indexOf(t) !== -1) {
        return {
            mode: t,
            scene: t === "first-flight" ? "arrival" : "",
            view: t === "explore" ? "features" : "",
            category: "",
            unknown: false
        };
    }
    if (FIRST_FLIGHT_SCENES.indexOf(t) !== -1) {
        return { mode: "first-flight", scene: t, view: "", category: "", unknown: false };
    }
    if (Object.prototype.hasOwnProperty.call(LEGACY_PAGE_MAP, t)) {
        var mapped = LEGACY_PAGE_MAP[t];
        return {
            mode: mapped.mode,
            scene: mapped.scene || "",
            view: mapped.view || "",
            category: mapped.category || "",
            unknown: false
        };
    }
    return { mode: "first-flight", scene: "arrival", view: "", category: "", unknown: true };
}

function evaluateStartup(state, sessionMarkerExists, sessionNoted, currentReleaseVersion, hasUnseenRelease) {
    if (!state || state.showOnLogin !== true || sessionMarkerExists === true || sessionNoted === true) {
        return { shouldOpen: false, target: "", mode: "", reason: "suppressed" };
    }
    if (state.firstRunCompleted !== true) {
        return { shouldOpen: true, target: "first-flight", mode: "first-flight", reason: "first-run" };
    }
    // Never replay First Flight once completed.
    if (hasUnseenRelease === true && currentReleaseVersion) {
        return { shouldOpen: true, target: "whats-new", mode: "whats-new", reason: "release-update" };
    }
    return { shouldOpen: false, target: "", mode: "", reason: "already-completed" };
}

function isSafeIdentifier(value, allowHash) {
    var s = String(value || "").trim();
    if (s === "" || s.length > 96)
        return false;
    if (s.indexOf("..") !== -1 || s.indexOf("://") !== -1 || s.indexOf(" ") !== -1)
        return false;
    var re = allowHash ? /^[a-zA-Z0-9._#-]+$/ : /^[a-zA-Z0-9._-]+$/;
    return re.test(s);
}

// Strict typed deep-link validator. Rejects arbitrary commands, URLs,
// path traversal, and unknown action types.
function validateTypedAction(actionOrUri) {
    if (!actionOrUri)
        return { valid: false, reason: "empty action" };

    if (typeof actionOrUri === "string") {
        var uri = actionOrUri.trim();
        var lower = uri.toLowerCase();
        if (lower.indexOf("http://") === 0 || lower.indexOf("https://") === 0 || lower.indexOf("javascript:") === 0 || lower.indexOf("file:") === 0)
            return { valid: false, reason: "external or unsafe URL scheme rejected" };
        var sep = uri.indexOf("://");
        if (sep <= 0)
            return { valid: false, reason: "missing scheme" };
        var scheme = uri.slice(0, sep);
        var rest = uri.slice(sep + 3);
        if (scheme === "welcome")
            return validateTypedAction({ type: "welcome", target: rest });
        if (scheme === "controlCenter") {
            var hashIdx = rest.indexOf("#");
            var pane = hashIdx >= 0 ? rest.slice(0, hashIdx) : rest;
            var sec = hashIdx >= 0 ? rest.slice(hashIdx + 1) : "";
            return validateTypedAction({ type: "controlCenter", target: pane, section: sec });
        }
        if (scheme === "drawer")
            return validateTypedAction({ type: "drawer", target: rest });
        if (scheme === "apps")
            return validateTypedAction({ type: "apps", target: rest });
        if (scheme === "action")
            return validateTypedAction({ type: "action", target: rest });
        return { valid: false, reason: "unknown URI scheme: " + scheme };
    }

    if (typeof actionOrUri !== "object" || Array.isArray(actionOrUri))
        return { valid: false, reason: "invalid action payload" };

    var type = String(actionOrUri.type || "").trim();
    var target = String(actionOrUri.target || "").trim();
    var section = String(actionOrUri.section || "").trim();

    if (type === "welcome") {
        if (!isValidTarget(target))
            return { valid: false, reason: "unknown welcome target: " + target };
        return { valid: true, type: "welcome", target: target.toLowerCase(), section: "" };
    }
    if (type === "controlCenter") {
        if (!isSafeIdentifier(target, false))
            return { valid: false, reason: "invalid controlCenter pane: " + target };
        if (section !== "" && !isSafeIdentifier(section, false))
            return { valid: false, reason: "invalid controlCenter section: " + section };
        return { valid: true, type: "controlCenter", target: target, section: section };
    }
    if (type === "drawer") {
        if (ALLOWED_DRAWERS.indexOf(target) === -1)
            return { valid: false, reason: "disallowed drawer: " + target };
        return { valid: true, type: "drawer", target: target, section: "" };
    }
    if (type === "apps") {
        if (target !== "" && !isSafeIdentifier(target, false))
            return { valid: false, reason: "invalid apps target: " + target };
        return { valid: true, type: "apps", target: target || "discover", section: "" };
    }
    if (type === "action") {
        if (ALLOWED_ACTIONS.indexOf(target) === -1)
            return { valid: false, reason: "disallowed action: " + target };
        return { valid: true, type: "action", target: target, section: "" };
    }
    return { valid: false, reason: "unknown action type: " + type };
}

function evaluateCapability(requires, caps) {
    var req = String(requires || "none").trim();
    var c = caps || {};
    if (req === "" || req === "none")
        return { available: true, reason: "" };
    if (req === "hyprland") {
        return c.hyprland === true
            ? { available: true, reason: "" }
            : { available: false, reason: "Hyprland session required" };
    }
    if (req === "studioAudio") {
        return c.studioAudio === true
            ? { available: true, reason: "" }
            : { available: false, reason: "Studio low-latency audio not configured" };
    }
    if (req === "companion") {
        return c.companion !== false
            ? { available: true, reason: "" }
            : { available: false, reason: "Javi companion is disabled" };
    }
    if (req === "assistantGateway") {
        return c.assistantGateway === true
            ? { available: true, reason: "" }
            : { available: false, reason: "Optional local Hermes assistant is not enabled" };
    }
    if (req === "btrfsSnapshots") {
        return c.btrfsSnapshots === true
            ? { available: true, reason: "" }
            : { available: false, reason: "OS Btrfs snapshots are not configured on this disk" };
    }
    return { available: true, reason: "" };
}

function _scoreMatch(q, title, summary, keywords) {
    if (q === "")
        return 10;
    var t = String(title || "").toLowerCase();
    var s = String(summary || "").toLowerCase();
    var kw = Array.isArray(keywords) ? keywords.join(" ").toLowerCase() : String(keywords || "").toLowerCase();
    if (t === q)
        return 100;
    if (t.indexOf(q) === 0)
        return 85;
    if (t.indexOf(q) !== -1)
        return 70;
    if (kw.indexOf(q) !== -1)
        return 50;
    if (s.indexOf(q) !== -1)
        return 30;
    return 0;
}

// Unified discovery search across features.json, live shortcuts, catalog apps,
// and extensions. Returns sorted, capability-annotated entries.
function searchDiscovery(query, features, shortcuts, apps, extensions, caps) {
    var q = String(query || "").trim().toLowerCase();
    var results = [];
    var i;

    if (Array.isArray(features)) {
        for (i = 0; i < features.length; i++) {
            var f = features[i];
            if (!f || !f.id)
                continue;
            var fScore = _scoreMatch(q, f.title, f.summary, (f.keywords || []).concat([f.category || ""]));
            if (fScore <= 0)
                continue;
            var cap = evaluateCapability(f.requires, caps);
            results.push({
                kind: "feature",
                id: String(f.id),
                title: String(f.title || f.id),
                subtitle: String(f.summary || ""),
                category: String(f.category || "General"),
                badge: String(f.availability || "supported"),
                available: cap.available,
                unavailableReason: cap.reason,
                icon: String(f.icon || "compass"),
                action: f.action || null,
                score: fScore + 5
            });
        }
    }

    if (Array.isArray(shortcuts)) {
        for (i = 0; i < shortcuts.length; i++) {
            var sc = shortcuts[i];
            if (!sc || !sc.label)
                continue;
            var scScore = _scoreMatch(q, sc.label, sc.keys, [sc.group || "", "shortcut", "keybind"]);
            if (scScore <= 0)
                continue;
            results.push({
                kind: "shortcut",
                id: String(sc.id || sc.keys || i),
                title: String(sc.label),
                subtitle: String(sc.keys || ""),
                category: String(sc.group || "Shortcuts"),
                badge: String(sc.keys || ""),
                available: true,
                unavailableReason: "",
                icon: "keyboard",
                action: { type: "welcome", target: "shortcuts" },
                score: scScore
            });
        }
    }

    if (Array.isArray(apps)) {
        for (i = 0; i < apps.length; i++) {
            var app = apps[i];
            if (!app || !app.id)
                continue;
            var appScore = _scoreMatch(q, app.name, app.summary, (app.categories || []).concat(app.tags || []));
            if (appScore <= 0)
                continue;
            results.push({
                kind: "app",
                id: String(app.id),
                title: String(app.name || app.id),
                subtitle: String(app.summary || ""),
                category: "Hornero Apps",
                badge: app.installed ? "Installed" : "Catalog",
                available: true,
                unavailableReason: "",
                icon: "apps",
                action: { type: "apps", target: String(app.id) },
                score: appScore
            });
        }
    }

    if (Array.isArray(extensions)) {
        for (i = 0; i < extensions.length; i++) {
            var ext = extensions[i];
            if (!ext || !ext.id)
                continue;
            var extScore = _scoreMatch(q, ext.name || ext.id, ext.description, [ext.category || "", "extension", "plugin"]);
            if (extScore <= 0)
                continue;
            results.push({
                kind: "extension",
                id: String(ext.id),
                title: String(ext.name || ext.id),
                subtitle: String(ext.description || ""),
                category: "Extensions",
                badge: ext.installed ? "Installed" : "Extension",
                available: true,
                unavailableReason: "",
                icon: "puzzle",
                action: { type: "controlCenter", target: "extensions", section: "" },
                score: extScore
            });
        }
    }

    results.sort(function (a, b) {
        if (b.score !== a.score)
            return b.score - a.score;
        return a.title.localeCompare(b.title);
    });
    return results;
}
