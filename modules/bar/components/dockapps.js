.pragma library

// Pure running-window dock model (HorneroOS/shell#737): merges pinned
// desktop entries with live compositor window summaries across Hyprland,
// Niri, and Wayland ToplevelManager, supporting running indicators,
// focus cycling, and unpinned running apps in dock mode.

function normalizeAppId(raw) {
    var s = String(raw || "").trim().toLowerCase();
    if (s.endsWith(".desktop"))
        s = s.slice(0, -8);
    return s;
}

function shortAppId(raw) {
    var norm = normalizeAppId(raw);
    var dot = norm.lastIndexOf(".");
    return dot >= 0 ? norm.slice(dot + 1) : norm;
}

function entryKeys(entry) {
    var keys = [];
    if (!entry)
        return keys;
    var candidates = [entry.id, entry.startupClass, entry.name];
    for (var i = 0; i < candidates.length; i++) {
        var norm = normalizeAppId(candidates[i]);
        if (norm && keys.indexOf(norm) === -1)
            keys.push(norm);
        var shortId = shortAppId(norm);
        if (shortId && keys.indexOf(shortId) === -1)
            keys.push(shortId);
    }
    return keys;
}

function matchesEntry(appClass, entry) {
    var cls = normalizeAppId(appClass);
    if (!cls)
        return false;
    var clsShort = shortAppId(cls);
    var keys = entryKeys(entry);
    return keys.indexOf(cls) !== -1 || (clsShort && keys.indexOf(clsShort) !== -1);
}

function findEntryForClass(appClass, allEntries) {
    if (!Array.isArray(allEntries))
        return null;
    for (var i = 0; i < allEntries.length; i++) {
        if (matchesEntry(appClass, allEntries[i]))
            return allEntries[i];
    }
    return null;
}

function buildDockItems(pinnedEntries, allEntries, windows, includeRunningUnpinned) {
    var pinned = Array.isArray(pinnedEntries) ? pinnedEntries : [];
    var winList = Array.isArray(windows) ? windows : [];
    var matchedWinIds = {};
    var fallbackDesktopEntry = "application-x-executable";
    var items = [];

    for (var i = 0; i < pinned.length; i++) {
        var entry = pinned[i];
        if (!entry)
            continue;
        var matched = [];
        var isActive = false;
        for (var j = 0; j < winList.length; j++) {
            var w = winList[j];
            if (!w)
                continue;
            if (matchesEntry(w.appClass, entry)) {
                matched.push(w);
                matchedWinIds[j] = true;
                if (w.activated)
                    isActive = true;
            }
        }
        items.push({
            id: normalizeAppId(entry.id || entry.name),
            name: entry.name || entry.id || "",
            icon: entry.icon || fallbackDesktopEntry,
            entry: entry,
            windows: matched,
            runningCount: matched.length,
            active: isActive,
            pinned: true
        });
    }

    if (!includeRunningUnpinned)
        return items;

    var unpinnedByClass = {};
    var unpinnedOrder = [];
    for (var k = 0; k < winList.length; k++) {
        if (matchedWinIds[k])
            continue;
        var win = winList[k];
        if (!win)
            continue;
        var clsKey = normalizeAppId(win.appClass || win.title || ("win-" + k));
        if (!clsKey)
            continue;
        if (!unpinnedByClass[clsKey]) {
            var resolved = findEntryForClass(win.appClass, allEntries);
            unpinnedByClass[clsKey] = {
                id: clsKey,
                name: (resolved && resolved.name) || win.appClass || win.title || clsKey,
                icon: (resolved && resolved.icon) || win.appClass || fallbackDesktopEntry,
                entry: resolved,
                windows: [],
                runningCount: 0,
                active: false,
                pinned: false
            };
            unpinnedOrder.push(clsKey);
        }
        var bucket = unpinnedByClass[clsKey];
        bucket.windows.push(win);
        bucket.runningCount = bucket.windows.length;
        if (win.activated)
            bucket.active = true;
    }

    for (var u = 0; u < unpinnedOrder.length; u++)
        items.push(unpinnedByClass[unpinnedOrder[u]]);

    return items;
}

function nextFocusWindow(windows) {
    if (!Array.isArray(windows) || windows.length === 0)
        return null;
    for (var i = 0; i < windows.length; i++) {
        if (windows[i] && windows[i].activated)
            return windows[(i + 1) % windows.length];
    }
    return windows[0];
}
