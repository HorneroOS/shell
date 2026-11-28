.pragma library

// Hornero Apps software center pure data & envelope parsers.
//
// Tested headlessly under node in tests/test_store.py as well as imported
// by QML modules (modules/apps/, modules/launcher/, modules/welcome/).
// Nothing here spawns processes, touches files, or performs network I/O.
//
// horneroctl --json emits { command, ok, message, data } where `data` is a
// map<string, string> — nested lists/objects are JSON-encoded strings inside
// `env.data` (or already-parsed arrays/objects in tests or future schemas).
// Every parser handles both representations defensively.

var VERIFIED_PROVENANCES = {
    "vendor_official_repo": true,
    "vendor_official_binary": true,
    "vendor_official": true,
    "arch_official": true,
    "hornero_official": true,
    "flathub_verified": true
};

var GUIDED_PROVENANCES = {
    "guided_setup_required": true
};

var WEBAPP_PROVENANCES = {
    "official_web_app": true
};

var COMMUNITY_AUR_PROVENANCES = {
    "community_package": true
};

var ICON_ALIASES = {
    "gamepad-2": "device-gamepad-2",
    "award": "star",
    "bot": "robot",
    "globe": "world",
    "message-circle": "message",
    "code-2": "code",
    "play-circle": "player-play",
    "wrench": "tool",
    "shield-check": "shield-lock",
    "graduation-cap": "school"
};

function _isSpanishLocale(locale) {
    return String(locale || "").trim().toLowerCase().indexOf("es") === 0;
}

function _normalizeIcon(icon, fallback) {
    var raw = String(icon || "").trim();
    if (raw.length === 0)
        return fallback || "apps";
    var lower = raw.toLowerCase();
    return ICON_ALIASES[lower] || raw;
}

function _parseEnvelope(rawJson) {
    if (rawJson === null || rawJson === undefined)
        return null;
    if (typeof rawJson === "object")
        return Array.isArray(rawJson) ? null : rawJson;
    if (typeof rawJson !== "string")
        return null;
    var trimmed = rawJson.trim();
    if (trimmed.length === 0)
        return null;
    try {
        var parsed = JSON.parse(trimmed);
        return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : null;
    } catch (e) {
        return null;
    }
}

function _parseJsonArray(val) {
    if (Array.isArray(val))
        return val;
    if (typeof val === "string") {
        var trimmed = val.trim();
        if (trimmed.length === 0)
            return [];
        try {
            var parsed = JSON.parse(trimmed);
            return Array.isArray(parsed) ? parsed : [];
        } catch (e) {
            return [];
        }
    }
    return [];
}

function _parseJsonObject(val) {
    if (val && typeof val === "object" && !Array.isArray(val))
        return val;
    if (typeof val === "string") {
        var trimmed = val.trim();
        if (trimmed.length === 0)
            return null;
        try {
            var parsed = JSON.parse(trimmed);
            return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : null;
        } catch (e) {
            return null;
        }
    }
    return null;
}

function _parseBool(val, fallback) {
    if (val === true || val === "true" || val === 1 || val === "1")
        return true;
    if (val === false || val === "false" || val === 0 || val === "0")
        return false;
    return fallback !== undefined ? fallback : false;
}

function _parseIntOr(val, fallback) {
    if (typeof val === "number" && isFinite(val))
        return Math.round(val);
    if (typeof val === "string" && val.trim().length > 0) {
        var n = parseInt(val, 10);
        if (!isNaN(n))
            return n;
    }
    return fallback;
}

function _firstLine(msg, fallback) {
    var text = (msg !== undefined && msg !== null) ? String(msg).trim() : "";
    if (text.length === 0)
        return fallback;
    return text.split("\n")[0];
}

function _stringList(val) {
    return _parseJsonArray(val).map(function (item) {
        if (typeof item === "string")
            return item.trim();
        if (item && typeof item === "object")
            return String(item.id || item.name || item.slug || item.label || "").trim();
        return String(item || "").trim();
    }).filter(function (s) {
        return s.length > 0;
    });
}

function provenanceLabel(prov) {
    var key = String(prov || "").trim().toLowerCase();
    if (key === "vendor_official_repo" || key === "vendor_official_binary" || key === "vendor_official")
        return "Official Vendor";
    if (key === "arch_official")
        return "Arch Official";
    if (key === "hornero_official")
        return "Hornero Official";
    if (key === "flathub_verified")
        return "Flathub Verified";
    if (key === "flathub_community")
        return "Community Flathub";
    if (key === "community_package" || key === "aur")
        return "Community AUR";
    if (key === "official_web_app" || key === "webapp")
        return "Official Web App";
    if (key === "guided_setup_required" || key === "guided")
        return "Guided Setup";
    if (key === "appimage" || key === "local_appimage")
        return "Local AppImage";
    return "Unverified";
}

function provenanceBadgeTone(prov) {
    var key = String(prov || "").trim().toLowerCase();
    if (key === "vendor_official_repo" || key === "vendor_official_binary" || key === "vendor_official" || key === "arch_official" || key === "hornero_official" || key === "flathub_verified")
        return "phosphor";
    if (key === "official_web_app" || key === "webapp" || key === "flathub_community")
        return "cue";
    if (key === "community_package" || key === "aur" || key === "guided_setup_required" || key === "guided" || key === "appimage" || key === "local_appimage")
        return "signal";
    return "alert";
}

function backendLabel(backend) {
    var key = String(backend || "").trim().toLowerCase();
    if (key === "pacman" || key === "arch" || key === "arch_official" || key === "arch_native")
        return "Arch / pacman";
    if (key === "flatpak" || key === "flathub")
        return "Flatpak";
    if (key === "appimage")
        return "AppImage";
    if (key === "webapp" || key === "pwa")
        return "Web App";
    if (key === "aur")
        return "Community AUR";
    if (key === "vendor" || key === "vendor_official" || key === "vendor_repo" || key === "hornero")
        return "Vendor Channel";
    if (key === "guided" || key === "guided_setup")
        return "Guided Setup";
    if (key === "external")
        return "System Package";
    return key.length > 0 ? key : "Unknown";
}

function backendShortPill(backend) {
    var key = String(backend || "").trim().toLowerCase();
    if (key === "pacman" || key === "arch" || key === "arch_official" || key === "arch_native")
        return "ARCH";
    if (key === "flatpak" || key === "flathub")
        return "FLATPAK";
    if (key === "appimage")
        return "APPIMAGE";
    if (key === "webapp" || key === "pwa")
        return "WEBAPP";
    if (key === "aur")
        return "AUR";
    if (key === "vendor" || key === "vendor_official" || key === "vendor_repo" || key === "hornero")
        return "VENDOR";
    if (key === "guided" || key === "guided_setup")
        return "GUIDE";
    return "APP";
}

function statusLabel(status) {
    var key = String(status || "").trim().toLowerCase();
    if (key === "installed")
        return "Installed";
    if (key === "update_available" || key === "outdated")
        return "Update available";
    if (key === "queued")
        return "Queued";
    if (key === "installing")
        return "Installing";
    if (key === "removing")
        return "Removing";
    if (key === "updating")
        return "Updating";
    if (key === "guided" || key === "guided_setup_required")
        return "Guided setup";
    if (key === "blocked" || key === "policy_blocked")
        return "Blocked by policy";
    if (key === "failed" || key === "error")
        return "Failed";
    return "Available";
}

function isVerifiedProvenance(prov) {
    var key = String(prov || "").trim().toLowerCase();
    return VERIFIED_PROVENANCES[key] === true;
}

function _normalizeSource(raw, isRecommended, locale) {
    if (!raw || typeof raw !== "object")
        return null;
    var isEs = _isSpanishLocale(locale);
    var backend = String(raw.backend || raw.type || "").trim().toLowerCase();
    var provenance = String(raw.provenance || raw.trust || "").trim().toLowerCase();
    var sourceId = String(raw.id || raw.source_id || raw.package_id || raw.package || raw.ref || backend || "");
    if (sourceId.length === 0 && backend.length === 0)
        return null;
    return {
        id: sourceId,
        backend: backend,
        provenance: provenance,
        packageName: String(raw.package_id || raw.package || raw.ref || raw.app_id || raw.id || ""),
        remote: String(raw.remote || raw.repo || ""),
        scope: String(raw.scope || ""),
        reason: String((isEs && (raw.recommended_reason_es || raw.reason_es)) || raw.recommended_reason || raw.reason || raw.why || ""),
        url: String(raw.url || raw.pkgbuild_url || raw.guide_url || ""),
        checksum: String(raw.sha256 || raw.checksum || ""),
        verified: raw.verified !== undefined ? _parseBool(raw.verified, false) : isVerifiedProvenance(provenance),
        recommended: _parseBool(raw.recommended, !!isRecommended)
    };
}

function _normalizeApp(raw, locale) {
    if (!raw || typeof raw !== "object")
        return null;
    var isEs = _isSpanishLocale(locale);
    var id = String(raw.id || raw.app_id || raw.slug || "").trim();
    if (id.length === 0)
        return null;
    var name = String((isEs && raw.name_es) || raw.name || raw.title || id);
    var summary = String((isEs && raw.summary_es) || raw.summary || raw.tagline || "");
    var description = String((isEs && raw.description_es) || raw.description || summary || "");

    var recRaw = raw.recommended_source !== undefined ? raw.recommended_source : raw.recommendedSource;
    var parsedRecObj = _parseJsonObject(recRaw);
    var recSrc = parsedRecObj ? _normalizeSource(parsedRecObj, true, locale) : null;
    var altRaw = _parseJsonArray(raw.alternative_sources !== undefined ? raw.alternative_sources : (raw.alternativeSources !== undefined ? raw.alternativeSources : raw.sources));
    var altSources = [];
    for (var i = 0; i < altRaw.length; i++) {
        var norm = _normalizeSource(altRaw[i], false, locale);
        if (norm)
            altSources.push(norm);
    }

    if (!recSrc && typeof recRaw === "string") {
        var recKey = recRaw.trim().toLowerCase();
        if (recKey.length > 0 && altSources.length > 0) {
            var matchedIdx = -1;
            for (var ri = 0; ri < altSources.length; ri++) {
                if (altSources[ri].backend === recKey || altSources[ri].id.toLowerCase() === recKey) {
                    matchedIdx = ri;
                    break;
                }
            }
            if (matchedIdx === -1)
                matchedIdx = 0;
            var chosen = altSources[matchedIdx];
            recSrc = {
                id: chosen.id,
                backend: chosen.backend,
                provenance: chosen.provenance,
                packageName: chosen.packageName,
                remote: chosen.remote,
                scope: chosen.scope,
                reason: chosen.reason,
                url: chosen.url,
                checksum: chosen.checksum,
                verified: chosen.verified,
                recommended: true
            };
        }
    }

    var backend = String(raw.backend || (recSrc ? recSrc.backend : "") || (typeof recRaw === "string" && !parsedRecObj ? recRaw : "") || "").trim().toLowerCase();
    var provenance = String(raw.provenance || (recSrc ? recSrc.provenance : "") || "").trim().toLowerCase();
    if (!recSrc && (backend.length > 0 || provenance.length > 0)) {
        recSrc = {
            id: String(raw.package_id || raw.package || raw.ref || id),
            backend: backend,
            provenance: provenance,
            packageName: String(raw.package_id || raw.package || raw.ref || id),
            remote: String(raw.remote || ""),
            scope: String(raw.scope || ""),
            reason: String((isEs && raw.recommended_reason_es) || raw.recommended_reason || raw.why_recommended || ""),
            url: String(raw.url || raw.web_app_url || raw.setup_guide_url || ""),
            checksum: String(raw.sha256 || ""),
            verified: raw.verified !== undefined ? _parseBool(raw.verified, false) : isVerifiedProvenance(provenance),
            recommended: true
        };
    }

    var installed = _parseBool(raw.installed, false);
    var updateAvailable = _parseBool(raw.update_available !== undefined ? raw.update_available : raw.updateAvailable, false);
    var status = String(raw.status || "");
    if (status.length === 0) {
        if (updateAvailable)
            status = "update_available";
        else if (installed)
            status = "installed";
        else if (GUIDED_PROVENANCES[provenance] || backend === "guided")
            status = "guided";
        else
            status = "available";
    }

    var categories = _stringList(raw.categories !== undefined ? raw.categories : raw.category);
    if (categories.length === 0 && typeof raw.category === "string" && raw.category.trim().length > 0)
        categories = [raw.category.trim()];

    var collections = _stringList(raw.collections !== undefined ? raw.collections : raw.collection);
    var aliases = _stringList(raw.aliases);
    var tags = _stringList(raw.tags);

    var isOpenSource = _parseBool(
        raw.is_open_source !== undefined ? raw.is_open_source : (raw.isOpenSource !== undefined ? raw.isOpenSource : raw.open_source),
        false
    );

    var verified = raw.verified !== undefined
        ? _parseBool(raw.verified, false)
        : (isVerifiedProvenance(provenance) || (recSrc ? recSrc.verified : false));

    var guidedOnly = _parseBool(raw.guided_only !== undefined ? raw.guided_only : raw.guidedOnly, false)
        || GUIDED_PROVENANCES[provenance] === true
        || backend === "guided"
        || backend === "guided_setup";

    var desktopId = String(raw.desktop_id || raw.desktopId || raw.flatpak_id || "");
    var webAppUrl = String(raw.web_app_url || raw.webAppUrl || (provenance === "official_web_app" || backend === "webapp" ? (raw.url || (recSrc ? recSrc.url : "")) : ""));
    var setupGuide = String(raw.setup_guide || raw.setupGuide || raw.guide_text || "");
    var setupGuideUrl = String(raw.setup_guide_url || raw.setupGuideUrl || raw.docs_url || raw.homepage || "");
    var pkgbuildUrl = String(raw.pkgbuild_url || raw.pkgbuildUrl || "");

    return {
        id: id,
        name: name,
        summary: summary,
        description: description,
        publisher: String(raw.publisher || raw.developer || raw.vendor || ""),
        icon: String(raw.icon || ""),
        categories: categories,
        collections: collections,
        tags: tags,
        aliases: aliases,
        license: String(raw.license || ""),
        isOpenSource: isOpenSource,
        pricing: String(raw.pricing || raw.price || (isOpenSource ? "Free & Open Source" : "Free")),
        stability: String(raw.stability || raw.maturity || "Stable"),
        provenance: provenance,
        backend: backend,
        verified: verified,
        guidedOnly: guidedOnly,
        recommendedSource: recSrc,
        alternativeSources: altSources,
        installed: installed,
        installedVersion: String(raw.installed_version || raw.installedVersion || raw.version || ""),
        latestVersion: String(raw.latest_version || raw.latestVersion || raw.version || ""),
        updateAvailable: updateAvailable,
        status: status,
        desktopId: desktopId,
        launchCommand: String(raw.launch_command || raw.exec || ""),
        permissions: _stringList(raw.permissions),
        waylandNotes: String(raw.wayland_notes || raw.waylandNotes || ""),
        gpuNotes: String(raw.gpu_notes || raw.gpuNotes || ""),
        sandboxNote: String(raw.sandbox_note || raw.sandboxNote || ""),
        setupGuide: setupGuide,
        setupGuideUrl: setupGuideUrl,
        webAppUrl: webAppUrl,
        pkgbuildUrl: pkgbuildUrl,
        homepage: String(raw.homepage || raw.url || ""),
        featured: _parseBool(raw.featured, false),
        aiCategory: String(raw.ai_category || raw.aiCategory || ""),
        externalDetected: _parseBool(raw.external || raw.externally_installed, false),
        sourceScope: String(raw.scope || (recSrc ? recSrc.scope : "") || "")
    };
}

function canOneClickInstall(app) {
    if (!app || typeof app !== "object")
        return false;
    var prov = String(app.provenance || "").trim().toLowerCase();
    var backend = String(app.backend || "").trim().toLowerCase();
    if (app.guidedOnly === true || GUIDED_PROVENANCES[prov] === true || backend === "guided" || backend === "guided_setup")
        return false;
    if (WEBAPP_PROVENANCES[prov] === true || backend === "webapp" || backend === "pwa")
        return false;
    if (COMMUNITY_AUR_PROVENANCES[prov] === true || backend === "aur")
        return false;
    if (app.verified === false && !isVerifiedProvenance(prov) && prov !== "flathub_community" && prov !== "appimage" && prov !== "local_appimage")
        return false;
    return backend.length > 0 || prov.length > 0;
}

function isAppBlockedByPolicy(app, policy) {
    if (!app || typeof app !== "object" || !policy || typeof policy !== "object")
        return false;
    if (policy.verifiedOnly === true && !isVerifiedProvenance(app.provenance) && app.verified !== true)
        return true;
    if (policy.openSourceOnly === true && app.isOpenSource !== true)
        return true;
    var backend = String(app.backend || "").toLowerCase();
    var prov = String(app.provenance || "").toLowerCase();
    if ((backend === "aur" || prov === "community_package") && String(policy.aurPolicy || "") === "disabled")
        return true;
    if (app.isOpenSource === false && String(policy.proprietaryPolicy || "") === "disabled")
        return true;
    if (Array.isArray(policy.allowedSources) && policy.allowedSources.length > 0) {
        var sourceKey = prov || backend;
        if (sourceKey.length > 0) {
            var matched = false;
            for (var i = 0; i < policy.allowedSources.length; i++) {
                var allowed = String(policy.allowedSources[i] || "").toLowerCase();
                if (allowed === sourceKey || allowed === backend || (allowed === "vendor_official" && (sourceKey === "vendor_official_repo" || sourceKey === "vendor_official_binary"))) {
                    matched = true;
                    break;
                }
            }
            if (!matched && !GUIDED_PROVENANCES[prov])
                return true;
        }
    }
    return false;
}

function primaryActionKind(app, policy) {
    if (!app || typeof app !== "object")
        return "guide";
    if (app.updateAvailable === true)
        return "update";
    if (app.installed === true)
        return "open";
    var prov = String(app.provenance || "").trim().toLowerCase();
    var backend = String(app.backend || "").trim().toLowerCase();
    if (app.guidedOnly === true || GUIDED_PROVENANCES[prov] === true || backend === "guided" || backend === "guided_setup")
        return "guide";
    if (WEBAPP_PROVENANCES[prov] === true || backend === "webapp" || backend === "pwa")
        return "webapp";
    if (isAppBlockedByPolicy(app, policy))
        return "policy_blocked";
    if (COMMUNITY_AUR_PROVENANCES[prov] === true || backend === "aur")
        return "aur_review";
    if (canOneClickInstall(app))
        return "install";
    return "guide";
}

function filterApps(apps, query, category, collection, verifiedOnly, openSourceOnly) {
    if (!Array.isArray(apps))
        return [];
    var q = (query !== undefined && query !== null) ? String(query).trim().toLowerCase() : "";
    var cat = (category !== undefined && category !== null) ? String(category).trim().toLowerCase() : "";
    var col = (collection !== undefined && collection !== null) ? String(collection).trim().toLowerCase() : "";
    var wantVerified = verifiedOnly === true;
    var wantOpen = openSourceOnly === true;

    return apps.filter(function (app) {
        if (!app || typeof app !== "object")
            return false;
        if (wantVerified && !isVerifiedProvenance(app.provenance) && app.verified !== true)
            return false;
        if (wantOpen && app.isOpenSource !== true)
            return false;
        if (cat.length > 0 && cat !== "all") {
            var cats = Array.isArray(app.categories) ? app.categories : [];
            var hasCat = cats.some(function (c) {
                return String(c).toLowerCase() === cat;
            });
            if (!hasCat)
                return false;
        }
        if (col.length > 0 && col !== "all") {
            var cols = Array.isArray(app.collections) ? app.collections : [];
            var hasCol = cols.some(function (c) {
                return String(c).toLowerCase() === col;
            });
            if (!hasCol)
                return false;
        }
        if (q.length > 0) {
            var haystack = [
                app.name,
                app.id,
                app.summary,
                app.publisher
            ].concat(app.aliases || [], app.categories || [], app.tags || []);
            var matched = haystack.some(function (field) {
                return String(field || "").toLowerCase().indexOf(q) !== -1;
            });
            if (!matched)
                return false;
        }
        return true;
    });
}

function filterUninstalledForLauncher(catalogApps, installedEntries, query, limit) {
    if (!Array.isArray(catalogApps))
        return [];
    var q = (query !== undefined && query !== null) ? String(query).trim().toLowerCase() : "";
    if (q.length < 2)
        return [];
    var maxItems = (typeof limit === "number" && limit > 0) ? limit : 4;
    var installedSet = {};
    if (Array.isArray(installedEntries)) {
        for (var i = 0; i < installedEntries.length; i++) {
            var e = installedEntries[i];
            if (typeof e === "string") {
                installedSet[e.toLowerCase()] = true;
            } else if (e && typeof e === "object") {
                if (e.id)
                    installedSet[String(e.id).toLowerCase().replace(/\.desktop$/, "")] = true;
                if (e.name)
                    installedSet[String(e.name).toLowerCase()] = true;
            }
        }
    }

    var matches = filterApps(catalogApps, q, "", "", false, false).filter(function (app) {
        if (app.installed === true)
            return false;
        var idKey = String(app.id || "").toLowerCase();
        var nameKey = String(app.name || "").toLowerCase();
        var desktopKey = String(app.desktopId || "").toLowerCase().replace(/\.desktop$/, "");
        if (installedSet[idKey] || installedSet[nameKey] || (desktopKey && installedSet[desktopKey]))
            return false;
        return true;
    });

    return matches.slice(0, maxItems).map(function (app) {
        return {
            isCatalogEntry: true,
            id: app.id,
            name: app.name,
            summary: app.summary,
            icon: app.icon,
            provenance: app.provenance,
            provenanceText: provenanceLabel(app.provenance),
            backend: app.backend,
            backendText: backendLabel(app.backend),
            backendPill: backendShortPill(app.backend),
            app: app
        };
    });
}

function parseStoreList(rawJson, locale) {
    var env = _parseEnvelope(rawJson);
    if (!env) {
        return {
            available: false,
            apps: [],
            total: 0,
            error: "horneroctl store is unavailable"
        };
    }
    if (env.ok !== true) {
        return {
            available: false,
            apps: [],
            total: 0,
            error: _firstLine(env.message, "store list failed")
        };
    }
    var data = env.data || {};
    var rawApps = _parseJsonArray(data.apps !== undefined ? data.apps : (data.items !== undefined ? data.items : data.results));
    var apps = [];
    for (var i = 0; i < rawApps.length; i++) {
        var norm = _normalizeApp(rawApps[i], locale);
        if (norm)
            apps.push(norm);
    }
    return {
        available: true,
        apps: apps,
        total: _parseIntOr(data.total, apps.length),
        error: ""
    };
}

function parseStoreSearch(rawJson, locale) {
    return parseStoreList(rawJson, locale);
}

function parseStoreShow(rawJson, locale) {
    var env = _parseEnvelope(rawJson);
    if (!env) {
        return {
            available: false,
            app: null,
            error: "horneroctl store is unavailable"
        };
    }
    if (env.ok !== true) {
        return {
            available: false,
            app: null,
            error: _firstLine(env.message, "store show failed")
        };
    }
    var data = env.data || {};
    var inner = _parseJsonObject(data.app);
    var merged = {};
    if (inner) {
        for (var k in inner) {
            if (Object.prototype.hasOwnProperty.call(inner, k))
                merged[k] = inner[k];
        }
    }
    for (var dk in data) {
        if (Object.prototype.hasOwnProperty.call(data, dk) && dk !== "app" && merged[dk] === undefined)
            merged[dk] = data[dk];
    }
    var app = _normalizeApp(merged, locale);
    if (!app) {
        return {
            available: false,
            app: null,
            error: "invalid app payload"
        };
    }
    return {
        available: true,
        app: app,
        error: ""
    };
}

function parseStoreCategories(rawJson, locale) {
    var env = _parseEnvelope(rawJson);
    if (!env)
        return { available: false, categories: [], error: "horneroctl store is unavailable" };
    if (env.ok !== true)
        return { available: false, categories: [], error: _firstLine(env.message, "store categories failed") };
    var isEs = _isSpanishLocale(locale);
    var data = env.data || {};
    var rawList = _parseJsonArray(data.categories);
    var categories = rawList.map(function (c) {
        if (typeof c === "string")
            return { id: c, name: c, description: "", icon: "category", count: 0 };
        if (!c || typeof c !== "object")
            return null;
        var id = String(c.id || c.slug || c.name || "");
        if (id.length === 0)
            return null;
        return {
            id: id,
            name: String((isEs && c.name_es) || c.name || c.title || id),
            description: String((isEs && c.description_es) || c.description || ""),
            icon: _normalizeIcon(c.icon, "category"),
            count: _parseIntOr(c.count, 0)
        };
    }).filter(function (c) { return c !== null; });
    return { available: true, categories: categories, error: "" };
}

function parseStoreCollections(rawJson, locale) {
    var env = _parseEnvelope(rawJson);
    if (!env)
        return { available: false, collections: [], error: "horneroctl store is unavailable" };
    if (env.ok !== true)
        return { available: false, collections: [], error: _firstLine(env.message, "store collections failed") };
    var isEs = _isSpanishLocale(locale);
    var data = env.data || {};
    var rawList = _parseJsonArray(data.collections);
    var collections = rawList.map(function (c) {
        if (typeof c === "string")
            return { id: c, name: c, description: "", icon: "folders", apps: [] };
        if (!c || typeof c !== "object")
            return null;
        var id = String(c.id || c.slug || c.name || "");
        if (id.length === 0)
            return null;
        return {
            id: id,
            name: String((isEs && c.name_es) || c.name || c.title || id),
            description: String((isEs && c.description_es) || c.description || ""),
            icon: _normalizeIcon(c.icon, "folders"),
            apps: _stringList(c.apps)
        };
    }).filter(function (c) { return c !== null; });
    return { available: true, collections: collections, error: "" };
}

function parseStoreProfiles(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env)
        return { available: false, profiles: [], error: "horneroctl store is unavailable" };
    if (env.ok !== true)
        return { available: false, profiles: [], error: _firstLine(env.message, "store profiles failed") };
    var data = env.data || {};
    var rawList = _parseJsonArray(data.profiles);
    var profiles = rawList.map(function (p) {
        if (!p || typeof p !== "object")
            return null;
        var id = String(p.id || p.slug || "");
        if (id.length === 0)
            return null;
        var rawApps = _parseJsonArray(p.apps);
        var apps = rawApps.map(function (a) {
            if (typeof a === "string")
                return { id: a, name: a, optional: false, installed: false, backend: "", provenance: "" };
            if (!a || typeof a !== "object")
                return null;
            var aid = String(a.id || a.app_id || "");
            if (aid.length === 0)
                return null;
            return {
                id: aid,
                name: String(a.name || aid),
                optional: _parseBool(a.optional, false),
                installed: _parseBool(a.installed, false),
                backend: String(a.backend || ""),
                provenance: String(a.provenance || "")
            };
        }).filter(function (a) { return a !== null; });
        return {
            id: id,
            name: String(p.name || p.title || id),
            description: String(p.description || ""),
            icon: String(p.icon || "apps"),
            apps: apps,
            appCount: _parseIntOr(p.app_count, apps.length)
        };
    }).filter(function (p) { return p !== null; });
    return { available: true, profiles: profiles, error: "" };
}

function parseStoreInstalled(rawJson, locale) {
    var res = parseStoreList(rawJson, locale);
    if (!res.available)
        return res;
    res.apps = res.apps.map(function (a) {
        a.installed = true;
        if (a.status === "available")
            a.status = "installed";
        return a;
    });
    return res;
}

function parseStoreUpdates(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env)
        return { available: false, updates: [], count: 0, error: "horneroctl store is unavailable" };
    if (env.ok !== true)
        return { available: false, updates: [], count: 0, error: _firstLine(env.message, "store update check failed") };
    var data = env.data || {};
    var rawList = _parseJsonArray(data.updates !== undefined ? data.updates : (data.apps !== undefined ? data.apps : data.packages));
    var updates = rawList.map(function (u) {
        if (typeof u === "string")
            return { id: u, name: u, backend: "", currentVersion: "", nextVersion: "" };
        if (!u || typeof u !== "object")
            return null;
        var id = String(u.id || u.app_id || u.package || u.name || "");
        if (id.length === 0)
            return null;
        return {
            id: id,
            name: String(u.name || u.title || id),
            backend: String(u.backend || ""),
            currentVersion: String(u.current_version || u.installed_version || u.from || ""),
            nextVersion: String(u.next_version || u.latest_version || u.to || "")
        };
    }).filter(function (u) { return u !== null; });
    return {
        available: true,
        updates: updates,
        count: _parseIntOr(data.count, updates.length),
        error: ""
    };
}

function parseStoreSources(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env)
        return { available: false, sources: [], error: "horneroctl store is unavailable" };
    if (env.ok !== true)
        return { available: false, sources: [], error: _firstLine(env.message, "store sources failed") };
    var data = env.data || {};
    var rawList = _parseJsonArray(data.sources !== undefined ? data.sources : data.backends);
    var sources = rawList.map(function (s) {
        if (!s || typeof s !== "object")
            return null;
        var id = String(s.id || s.backend || s.name || "");
        if (id.length === 0)
            return null;
        return {
            id: id,
            name: String(s.name || backendLabel(id)),
            available: _parseBool(s.available, false),
            enabled: _parseBool(s.enabled, true),
            ready: _parseBool(s.ready !== undefined ? s.ready : s.available, false),
            scope: String(s.scope || s.default_scope || ""),
            detail: String(s.detail || s.status || s.message || "")
        };
    }).filter(function (s) { return s !== null; });
    return { available: true, sources: sources, error: "" };
}

function parseStorePolicy(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env) {
        return {
            available: false,
            policy: {
                verifiedOnly: false,
                openSourceOnly: false,
                aurPolicy: "explicit_opt_in",
                proprietaryPolicy: "explicit_consent",
                flatpakDefaultScope: "user",
                allowedSources: []
            },
            error: "horneroctl store policy is unavailable"
        };
    }
    if (env.ok !== true) {
        return {
            available: false,
            policy: {
                verifiedOnly: false,
                openSourceOnly: false,
                aurPolicy: "explicit_opt_in",
                proprietaryPolicy: "explicit_consent",
                flatpakDefaultScope: "user",
                allowedSources: []
            },
            error: _firstLine(env.message, "store policy failed")
        };
    }
    var data = env.data || {};
    var inner = _parseJsonObject(data.policy) || data;
    return {
        available: true,
        policy: {
            verifiedOnly: _parseBool(inner.verified_only !== undefined ? inner.verified_only : inner.verifiedOnly, false),
            openSourceOnly: _parseBool(inner.open_source_only !== undefined ? inner.open_source_only : inner.openSourceOnly, false),
            aurPolicy: String(inner.aur_policy || inner.aurPolicy || "explicit_opt_in"),
            proprietaryPolicy: String(inner.proprietary_policy || inner.proprietaryPolicy || "explicit_consent"),
            flatpakDefaultScope: String(inner.flatpak_default_scope || inner.flatpakDefaultScope || "user"),
            allowedSources: _stringList(inner.allowed_sources !== undefined ? inner.allowed_sources : inner.allowedSources)
        },
        error: ""
    };
}

function parseStoreQueue(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env)
        return { available: false, items: [], running: false, error: "horneroctl store queue is unavailable" };
    if (env.ok !== true)
        return { available: false, items: [], running: false, error: _firstLine(env.message, "store queue failed") };
    var data = env.data || {};
    var rawList = _parseJsonArray(data.queue !== undefined ? data.queue : data.items);
    var items = rawList.map(function (q) {
        if (typeof q === "string")
            return { id: q, appId: q, name: q, action: "install", backend: "", status: "queued", error: "" };
        if (!q || typeof q !== "object")
            return null;
        var appId = String(q.app_id || q.id || "");
        if (appId.length === 0)
            return null;
        return {
            id: String(q.job_id || q.id || appId),
            appId: appId,
            name: String(q.name || appId),
            action: String(q.action || q.verb || "install"),
            backend: String(q.backend || ""),
            status: String(q.status || "queued"),
            error: String(q.error || "")
        };
    }).filter(function (q) { return q !== null; });
    return {
        available: true,
        items: items,
        running: _parseBool(data.running, false),
        error: ""
    };
}

function parseStoreDoctor(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env)
        return { available: false, healthy: false, checks: [], error: "horneroctl store doctor is unavailable" };
    if (env.ok !== true)
        return { available: false, healthy: false, checks: [], error: _firstLine(env.message, "store doctor failed") };
    var data = env.data || {};
    var rawChecks = _parseJsonArray(data.checks);
    var checks = rawChecks.map(function (c) {
        if (!c || typeof c !== "object")
            return null;
        return {
            id: String(c.id || c.name || ""),
            name: String(c.name || c.id || ""),
            ok: _parseBool(c.ok !== undefined ? c.ok : c.passed, false),
            status: String(c.status || ""),
            detail: String(c.detail || c.message || "")
        };
    }).filter(function (c) { return c !== null && c.name.length > 0; });
    return {
        available: true,
        healthy: data.healthy !== undefined ? _parseBool(data.healthy, true) : checks.every(function (c) { return c.ok; }),
        checks: checks,
        error: ""
    };
}

function parseStorePermissions(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env)
        return { available: false, sandboxed: false, permissions: [], note: "", error: "permissions unavailable" };
    if (env.ok !== true)
        return { available: false, sandboxed: false, permissions: [], note: "", error: _firstLine(env.message, "permissions check failed") };
    var data = env.data || {};
    return {
        available: true,
        sandboxed: _parseBool(data.sandboxed, false),
        permissions: _stringList(data.permissions),
        note: String(data.note || env.message || ""),
        error: ""
    };
}

function parseStoreAction(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env) {
        return {
            ok: false,
            message: "",
            error: "horneroctl store is unavailable",
            data: {}
        };
    }
    var ok = env.ok === true;
    return {
        ok: ok,
        message: String(env.message || ""),
        error: ok ? "" : _firstLine(env.message, "store operation failed"),
        data: env.data || {}
    };
}
