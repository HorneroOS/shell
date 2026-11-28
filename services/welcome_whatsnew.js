.pragma library

// Version-aware What's New engine for Hornero Welcome.
// Parses declarative releases.json, compares semver tags, filters release
// highlights by system capability, and evaluates unseen release status
// independently of firstRunCompleted.

function parseSemver(version) {
    var clean = String(version || "").trim().replace(/^v/i, "").split("-")[0];
    if (clean === "")
        return null;
    var parts = clean.split(".");
    if (parts.length === 0)
        return null;
    var out = [0, 0, 0];
    for (var i = 0; i < 3 && i < parts.length; i++) {
        var n = parseInt(parts[i], 10);
        if (isNaN(n) || n < 0)
            return null;
        out[i] = n;
    }
    return out;
}

function compareVersions(a, b) {
    var va = parseSemver(a);
    var vb = parseSemver(b);
    if (!va && !vb)
        return 0;
    if (!va)
        return -1;
    if (!vb)
        return 1;
    for (var i = 0; i < 3; i++) {
        if (va[i] > vb[i])
            return 1;
        if (va[i] < vb[i])
            return -1;
    }
    return 0;
}

function hasUnseenRelease(currentVersion, lastSeenReleaseVersion) {
    var cur = String(currentVersion || "").trim();
    if (cur === "")
        return false;
    var seen = String(lastSeenReleaseVersion || "").trim();
    if (seen === "")
        return true;
    return compareVersions(cur, seen) > 0;
}

function _capabilityMatches(requires, caps) {
    var req = String(requires || "none").trim();
    if (req === "" || req === "none")
        return true;
    var c = caps || {};
    if (req === "hyprland")
        return c.hyprland === true;
    if (req === "studioAudio")
        return c.studioAudio === true;
    if (req === "companion")
        return c.companion !== false;
    if (req === "assistantGateway")
        return c.assistantGateway === true;
    if (req === "btrfsSnapshots")
        return c.btrfsSnapshots === true;
    return true;
}

function filterReleases(releasesDoc, caps, lastSeenVersion) {
    if (!releasesDoc || typeof releasesDoc !== "object" || !Array.isArray(releasesDoc.releases))
        return [];
    var currentVer = String(releasesDoc.currentReleaseVersion || "");
    var out = [];
    for (var i = 0; i < releasesDoc.releases.length; i++) {
        var rel = releasesDoc.releases[i];
        if (!rel || typeof rel.version !== "string" || rel.version === "")
            continue;
        if (rel.requires && !_capabilityMatches(rel.requires, caps))
            continue;
        var highlights = [];
        if (Array.isArray(rel.highlights)) {
            for (var j = 0; j < rel.highlights.length; j++) {
                var h = rel.highlights[j];
                if (!h || !h.id || !h.title)
                    continue;
                if (h.requires && !_capabilityMatches(h.requires, caps))
                    continue;
                highlights.push({
                    id: String(h.id),
                    title: String(h.title),
                    summary: String(h.summary || ""),
                    availability: String(h.availability || "supported"),
                    icon: String(h.icon || "sparkles"),
                    action: h.action || null
                });
            }
        }
        out.push({
            version: String(rel.version),
            date: String(rel.date || ""),
            title: String(rel.title || ("HorneroOS " + rel.version)),
            summary: String(rel.summary || ""),
            isCurrent: currentVer !== "" && compareVersions(rel.version, currentVer) === 0,
            isUnseen: lastSeenVersion ? compareVersions(rel.version, lastSeenVersion) > 0 : false,
            highlights: highlights
        });
    }
    out.sort(function (a, b) {
        return compareVersions(b.version, a.version);
    });
    return out;
}

function latestRelease(releasesDoc, caps, lastSeenVersion) {
    var list = filterReleases(releasesDoc, caps, lastSeenVersion);
    return list.length > 0 ? list[0] : null;
}
