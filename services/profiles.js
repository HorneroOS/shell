.pragma library

// Universal Profiles, Snapshots, Companion Apps & Studio Live Routing helpers.
//
// Pure data + JSON envelope parsers so all defensive parsing, slugification,
// and zero-volume detection run under node in tests/test_profiles.py as well
// as inside QML panes. Nothing here spawns processes or touches files.
//
// horneroctl --json emits { command, ok, message, data } where `data` is a
// map<string, string> — nested lists/objects are JSON-encoded strings inside
// `env.data` (or already-parsed arrays/objects in tests or future schemas).
// Every parser handles both representations gracefully.

var PROFILE_DOMAINS = [
    { id: "experience", label: "Experience" },
    { id: "audio", label: "Audio & Routing" },
    { id: "power", label: "Power" },
    { id: "extensions", label: "Extensions" },
    { id: "apps", label: "Companion Apps" }
];

var ROUTING_KITS = [
    {
        id: "live-call",
        name: "Live Call Bus",
        description: "Virtual buses for mic, guitar DI, REAPER, Discord, and OBS."
    },
    {
        id: "browser-backing",
        name: "Browser Backing Sink",
        description: "Isolated loopback sink to route browser audio into your DAW."
    },
    {
        id: "reaper-low-latency",
        name: "REAPER Low-Latency JACK Rule",
        description: "Scoped 256/48000 scheduling period for REAPER via pipewire-jack."
    }
];

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

function _parseBool(val) {
    return val === true || val === "true" || val === 1 || val === "1";
}

function _firstLine(msg, fallback) {
    var text = (msg !== undefined && msg !== null) ? String(msg).trim() : "";
    if (text.length === 0)
        return fallback;
    return text.split("\n")[0];
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

function _normalizeAppItem(item) {
    if (typeof item === "string") {
        return {
            id: item,
            name: item,
            desktop_id: "",
            running: false
        };
    }
    if (!item || typeof item !== "object")
        return null;
    var id = String(item.id || item.app_id || item.name || item.binary || "");
    var name = String(item.name || item.title || item.label || id);
    return {
        id: id,
        name: name,
        desktop_id: String(item.desktop_id || ""),
        running: _parseBool(item.running)
    };
}

function _normalizeProfile(raw, activeId) {
    if (!raw || typeof raw !== "object")
        return null;
    var id = String(raw.id || "");
    if (id.length === 0)
        return null;
    var name = String(raw.name || id);
    var description = String(raw.description || "");
    var domains = _parseJsonArray(raw.domains).map(function (d) {
        return String(d);
    }).filter(function (d) {
        return d.length > 0;
    });
    var isBaseline = _parseBool(raw.is_baseline !== undefined ? raw.is_baseline : raw.baseline) || id === "baseline";
    var isActive = _parseBool(raw.is_active !== undefined ? raw.is_active : raw.active) || (!!activeId && id === activeId);
    var hardwareMissing = _parseJsonArray(raw.hardware_missing !== undefined ? raw.hardware_missing : raw.missing_hardware).map(function (h) {
        return typeof h === "string" ? h : String(h.name || h.id || h.description || JSON.stringify(h));
    });
    var hardwareOk = raw.hardware_ok !== undefined ? _parseBool(raw.hardware_ok) : hardwareMissing.length === 0;
    var companionApps = _parseJsonArray(raw.companion_apps !== undefined ? raw.companion_apps : raw.apps)
        .map(_normalizeAppItem)
        .filter(function (a) { return a !== null && a.id.length > 0; });
    var runningApps = _parseJsonArray(raw.running_apps)
        .map(_normalizeAppItem)
        .filter(function (a) { return a !== null && a.id.length > 0; });
    var missingApps = _parseJsonArray(raw.missing_apps)
        .map(_normalizeAppItem)
        .filter(function (a) { return a !== null && a.id.length > 0; });
    var appCount = _parseIntOr(raw.app_count, companionApps.length);
    var runningAppCount = raw.running_app_count !== undefined
        ? _parseIntOr(raw.running_app_count, 0)
        : (runningApps.length > 0 ? runningApps.length : Math.max(0, appCount - missingApps.length));
    return {
        id: id,
        name: name,
        description: description,
        domains: domains,
        isBaseline: isBaseline,
        isActive: isActive,
        hardwareOk: hardwareOk,
        hardwareMissing: hardwareMissing,
        companionApps: companionApps,
        runningApps: runningApps,
        missingApps: missingApps,
        appCount: appCount,
        runningAppCount: runningAppCount,
        capturedAt: String(raw.captured_at || raw.updated_at || "")
    };
}

function parseProfileList(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env) {
        return {
            available: false,
            active: "",
            hasBaseline: false,
            hasPrevious: false,
            profiles: [],
            error: "horneroctl profile is unavailable"
        };
    }
    if (env.ok !== true) {
        return {
            available: false,
            active: "",
            hasBaseline: false,
            hasPrevious: false,
            profiles: [],
            error: _firstLine(env.message, "profile list failed")
        };
    }
    var data = env.data || {};
    var active = String(data.active || data.active_profile || "");
    var rawList = _parseJsonArray(data.profiles);
    var profiles = [];
    for (var i = 0; i < rawList.length; i++) {
        var p = _normalizeProfile(rawList[i], active);
        if (p)
            profiles.push(p);
    }
    if (active.length === 0) {
        for (var j = 0; j < profiles.length; j++) {
            if (profiles[j].isActive) {
                active = profiles[j].id;
                break;
            }
        }
    }
    var hasBaseline = data.has_baseline !== undefined
        ? _parseBool(data.has_baseline)
        : profiles.some(function (p) { return p.isBaseline; });
    var hasPrevious = _parseBool(data.has_previous);
    return {
        available: true,
        active: active,
        hasBaseline: hasBaseline,
        hasPrevious: hasPrevious,
        profiles: profiles,
        error: ""
    };
}

function parseProfileShow(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env) {
        return {
            available: false,
            profile: null,
            id: "",
            name: "",
            description: "",
            domains: [],
            isBaseline: false,
            isActive: false,
            hardwareOk: true,
            hardwareMissing: [],
            companionApps: [],
            runningApps: [],
            missingApps: [],
            error: "horneroctl profile is unavailable"
        };
    }
    if (env.ok !== true) {
        return {
            available: false,
            profile: null,
            id: "",
            name: "",
            description: "",
            domains: [],
            isBaseline: false,
            isActive: false,
            hardwareOk: true,
            hardwareMissing: [],
            companionApps: [],
            runningApps: [],
            missingApps: [],
            error: _firstLine(env.message, "profile show failed")
        };
    }
    var data = env.data || {};
    var merged = {};
    var inner = _parseJsonObject(data.profile);
    if (inner) {
        for (var k in inner) {
            if (Object.prototype.hasOwnProperty.call(inner, k))
                merged[k] = inner[k];
        }
    }
    for (var dk in data) {
        if (Object.prototype.hasOwnProperty.call(data, dk) && dk !== "profile" && merged[dk] === undefined)
            merged[dk] = data[dk];
    }
    var active = String(data.active || data.active_profile || "");
    var prof = _normalizeProfile(merged, active);
    if (!prof) {
        return {
            available: false,
            profile: null,
            id: String(merged.id || ""),
            name: String(merged.name || ""),
            description: "",
            domains: [],
            isBaseline: false,
            isActive: false,
            hardwareOk: true,
            hardwareMissing: [],
            companionApps: [],
            runningApps: [],
            missingApps: [],
            error: "invalid profile payload"
        };
    }
    return {
        available: true,
        profile: prof,
        id: prof.id,
        name: prof.name,
        description: prof.description,
        domains: prof.domains,
        isBaseline: prof.isBaseline,
        isActive: prof.isActive,
        hardwareOk: prof.hardwareOk,
        hardwareMissing: prof.hardwareMissing,
        companionApps: prof.companionApps,
        runningApps: prof.runningApps,
        missingApps: prof.missingApps,
        error: ""
    };
}

function parseProfileDiff(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env) {
        return {
            available: false,
            id: "",
            name: "",
            changes: [],
            willRestartPipewire: false,
            hardwareMissing: [],
            missingApps: [],
            warnings: [],
            error: "horneroctl profile is unavailable"
        };
    }
    if (env.ok !== true) {
        return {
            available: false,
            id: "",
            name: "",
            changes: [],
            willRestartPipewire: false,
            hardwareMissing: [],
            missingApps: [],
            warnings: [],
            error: _firstLine(env.message, "profile diff failed")
        };
    }
    var data = env.data || {};
    var id = String(data.id || data.profile_id || "");
    var name = String(data.name || id);
    var changes = _parseJsonArray(data.changes).map(function (c) {
        if (typeof c === "string") {
            return { domain: "", key: "", from: "", to: "", summary: c };
        }
        if (c && typeof c === "object") {
            return {
                domain: String(c.domain || ""),
                key: String(c.key || c.field || ""),
                from: c.from !== undefined ? String(c.from) : "",
                to: c.to !== undefined ? String(c.to) : "",
                summary: String(c.summary || c.description || "")
            };
        }
        return { domain: "", key: "", from: "", to: "", summary: String(c) };
    });
    var willRestartPipewire = _parseBool(
        data.will_restart_pipewire !== undefined ? data.will_restart_pipewire : data.pipewire_restart
    );
    var hardwareMissing = _parseJsonArray(data.hardware_missing).map(function (h) {
        return typeof h === "string" ? h : String(h.name || h.id || h.description || JSON.stringify(h));
    });
    var missingApps = _parseJsonArray(data.missing_apps)
        .map(_normalizeAppItem)
        .filter(function (a) { return a !== null && a.id.length > 0; });
    var warnings = _parseJsonArray(data.warnings).map(function (w) {
        return typeof w === "string" ? w : String(w.message || w.summary || JSON.stringify(w));
    });
    return {
        available: true,
        id: id,
        name: name,
        changes: changes,
        willRestartPipewire: willRestartPipewire,
        hardwareMissing: hardwareMissing,
        missingApps: missingApps,
        warnings: warnings,
        error: ""
    };
}

function parseProfileApply(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env) {
        return {
            ok: false,
            id: "",
            pipewireRestarted: false,
            missingApps: [],
            warnings: [],
            message: "",
            error: "horneroctl profile is unavailable"
        };
    }
    var data = env.data || {};
    var ok = env.ok === true;
    var id = String(data.id || data.profile_id || data.active || "");
    var pipewireRestarted = _parseBool(
        data.pipewire_restarted !== undefined ? data.pipewire_restarted : data.pipewire_restart
    );
    var missingApps = _parseJsonArray(data.missing_apps)
        .map(_normalizeAppItem)
        .filter(function (a) { return a !== null && a.id.length > 0; });
    var warnings = _parseJsonArray(data.warnings).map(function (w) {
        return typeof w === "string" ? w : String(w.message || w.summary || JSON.stringify(w));
    });
    return {
        ok: ok,
        id: id,
        pipewireRestarted: pipewireRestarted,
        missingApps: missingApps,
        warnings: warnings,
        message: String(env.message || ""),
        error: ok ? "" : _firstLine(env.message, "profile apply failed")
    };
}

function findZeroVolumeStreams(streams) {
    if (!Array.isArray(streams))
        return [];
    var out = [];
    for (var i = 0; i < streams.length; i++) {
        var s = streams[i];
        if (!s || typeof s !== "object")
            continue;
        var hasWarning = _parseBool(s.zero_volume_warning);
        var hasZeroPct = false;
        if (typeof s.volume_pct === "number")
            hasZeroPct = isFinite(s.volume_pct) && s.volume_pct === 0;
        else if (typeof s.volume_pct === "string" && s.volume_pct.trim().length > 0) {
            var n = Number(s.volume_pct);
            hasZeroPct = isFinite(n) && n === 0;
        }
        var isMuted = _parseBool(s.muted);
        if (hasWarning || (hasZeroPct && !isMuted))
            out.push(s);
    }
    return out;
}

function parseRoutingStatus(rawJson) {
    var env = _parseEnvelope(rawJson);
    if (!env) {
        return {
            available: false,
            kits: [],
            streams: [],
            sinks: [],
            zeroVolumeStreams: [],
            error: "horneroctl studio routing is unavailable"
        };
    }
    if (env.ok !== true) {
        return {
            available: false,
            kits: [],
            streams: [],
            sinks: [],
            zeroVolumeStreams: [],
            error: _firstLine(env.message, "studio routing status failed")
        };
    }
    var data = env.data || {};
    var kits = _parseJsonArray(data.kits).map(function (k) {
        if (!k || typeof k !== "object")
            return null;
        return {
            id: String(k.id || ""),
            name: String(k.name || k.title || k.id || ""),
            description: String(k.description || ""),
            active: _parseBool(k.active !== undefined ? k.active : k.enabled),
            external: _parseBool(
                k.externally_managed !== undefined
                    ? k.externally_managed
                    : (k.external !== undefined ? k.external : k.read_only)
            ),
            configFile: String(k.config_file || k.path || "")
        };
    }).filter(function (k) { return k !== null && k.id.length > 0; });

    var streams = _parseJsonArray(data.streams).map(function (s) {
        if (!s || typeof s !== "object")
            return null;
        var pct = (s.volume_pct !== undefined && s.volume_pct !== null && String(s.volume_pct).trim().length > 0)
            ? Number(s.volume_pct)
            : -1;
        return {
            id: String(s.id !== undefined ? s.id : ""),
            name: String(s.name || s.app_name || s.binary || ("Stream " + s.id)),
            app_name: String(s.app_name || s.name || ""),
            binary: String(s.binary || ""),
            sink: String(s.sink || s.sink_name || ""),
            volume_pct: isFinite(pct) ? pct : -1,
            muted: _parseBool(s.muted),
            zero_volume_warning: _parseBool(s.zero_volume_warning)
        };
    }).filter(function (s) { return s !== null && s.id.length > 0; });

    var sinks = _parseJsonArray(data.sinks).map(function (sk) {
        if (!sk || typeof sk !== "object")
            return null;
        return {
            id: String(sk.id !== undefined ? sk.id : (sk.name || "")),
            name: String(sk.name || sk.id || ""),
            description: String(sk.description || sk.name || sk.id || ""),
            is_default: _parseBool(sk.is_default),
            active: _parseBool(sk.active !== undefined ? sk.active : true)
        };
    }).filter(function (sk) { return sk !== null && sk.name.length > 0; });

    return {
        available: true,
        kits: kits,
        streams: streams,
        sinks: sinks,
        zeroVolumeStreams: findZeroVolumeStreams(streams),
        error: ""
    };
}

function slugifyProfileId(name) {
    if (name === null || name === undefined)
        return "";
    var str = String(name).trim();
    if (str.length === 0)
        return "";
    try {
        str = str.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    } catch (e) {
        // Fallback if normalize is unavailable.
    }
    var slug = str.toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-+|-+$/g, "");
    if (slug.length > 64)
        slug = slug.slice(0, 64).replace(/-+$/g, "");
    return slug;
}
