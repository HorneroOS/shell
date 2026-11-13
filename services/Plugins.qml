pragma Singleton

import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Community plugin runtime state (M2). horneroctl is the single writer
// of lifecycle state (install/enable/disable/remove); this service only
// discovers what is enabled and tracks load outcomes for the host.
//
// Manifest v2 (shell#373): one package may declare several entry
// points in `surfaces` (background, bar, dashboard, desktop, plus the
// reserved launcher/settings declarations, which no host loads yet).
// Each entry keeps an effective `surfaces` map — name to
// {entrypoint, enabled} — derived by PluginHost from the manifest;
// v1 manifests derive exactly the single placement/entrypoint surface
// and behave as before. The per-surface lists below hand each host a
// copy of the entry whose `entrypoint` is that surface's file, so the
// hosts' Loader contract (modelData.id + modelData.entrypoint) is
// unchanged. Surfaces and capabilities are declarations only: naming
// one grants no privilege and enforces nothing at runtime.
//
// Trust label, stated once and never softened: enabled plugin QML runs
// inside Quickshell with the logged-in user's privileges. It is NOT
// sandboxed, and the static contract validator is not a security
// certification. Only enable plugins whose source you have reviewed.
Singleton {
    id: root

    // Entries: {id, name, version, enabled, installed, state, detail}
    // state: pending | loaded | failed | disabled
    property var entries: []
    property bool discovered: false
    property string discoveryError: ""
    property string buffer: ""
    readonly property bool loading: listProcess.running

    readonly property string pluginsDir: `${Paths.data}/plugins`

    function reload(): void {
        if (listProcess.running)
            return;
        root.buffer = "";
        root.discoveryError = "";
        listProcess.running = true;
    }

    // Normalize an effective-surfaces map from PluginHost: keep only
    // object values with a string entrypoint; `enabled` defaults to
    // true unless it is explicitly false. Malformed shapes were
    // already rejected by PluginHost's runtime manifest gate, so this
    // is defence in depth, never a second parser with new rules.
    function normalizeSurfaces(surfaces: var, placement: string, entrypoint: string): var {
        const normalized = ({});
        if (surfaces && typeof surfaces === "object" && !Array.isArray(surfaces)) {
            for (const name in surfaces) {
                const surface = surfaces[name];
                if (surface && typeof surface === "object" && !Array.isArray(surface)
                        && typeof surface.entrypoint === "string" && surface.entrypoint !== "")
                    normalized[name] = {
                        entrypoint: surface.entrypoint,
                        enabled: surface.enabled !== false
                    };
            }
        }
        if (Object.keys(normalized).length === 0 && placement !== "" && entrypoint !== "")
            normalized[placement] = {
                entrypoint: entrypoint,
                enabled: true
            };
        return normalized;
    }

    // Extension settings declarations (shell#374), canonical QML
    // mirror of scripts/validate_plugin.py: closed type set
    // (boolean, integer, number, string, enum — no path type, so no
    // setting can name a filesystem path for the shell to open) plus
    // per-type constraints. A declaration that does not satisfy its
    // own rules is dropped here, so the Settings facade and the
    // generated Control Center UI only ever see well-formed
    // declarations; well-formed v1 declarations pass through
    // unchanged. Defence in depth: installed manifests were already
    // validated by horneroctl/validate_plugin.py.
    function settingDeclarationValid(declaration: var): bool {
        if (!declaration || typeof declaration !== "object" || Array.isArray(declaration))
            return false;
        const allowed = {
            boolean: [],
            integer: ["minimum", "maximum"],
            number: ["minimum", "maximum"],
            string: ["minLength", "maxLength"],
            enum: ["options"]
        };
        if (!Object.prototype.hasOwnProperty.call(allowed, declaration.type))
            return false;
        const keys = Object.keys(declaration);
        const known = ["type", "default", "description"].concat(allowed[declaration.type]);
        if (!keys.every(key => known.includes(key)) || !keys.includes("default"))
            return false;
        if (declaration.description !== undefined
                && (typeof declaration.description !== "string" || declaration.description.length > 160
                    || !/\S/.test(declaration.description)))
            return false;
        if (declaration.type === "integer" || declaration.type === "number") {
            for (const bound of ["minimum", "maximum"]) {
                const limit = declaration[bound];
                if (limit !== undefined && (typeof limit !== "number" || !Number.isFinite(limit)
                        || (declaration.type === "integer" && !Number.isInteger(limit))))
                    return false;
            }
            if (declaration.minimum !== undefined && declaration.maximum !== undefined
                    && declaration.minimum > declaration.maximum)
                return false;
        }
        if (declaration.type === "string") {
            for (const bound of ["minLength", "maxLength"]) {
                const limit = declaration[bound];
                if (limit !== undefined && (typeof limit !== "number" || !Number.isInteger(limit) || limit < 0 || limit > 4096))
                    return false;
            }
            if (declaration.minLength !== undefined && declaration.maxLength !== undefined
                    && declaration.minLength > declaration.maxLength)
                return false;
        }
        if (declaration.type === "enum") {
            const options = declaration.options;
            if (!Array.isArray(options) || options.length === 0 || options.length > 32
                    || options.some(option => typeof option !== "string" || option === "" || option.length > 64)
                    || new Set(options).size !== options.length)
                return false;
        }
        return root.settingValueValid(declaration, declaration.default);
    }

    function normalizeSettings(settings: var): var {
        const normalized = ({});
        if (!settings || typeof settings !== "object" || Array.isArray(settings))
            return normalized;
        for (const key of Object.keys(settings)) {
            if (/^[a-z][a-zA-Z0-9]{0,47}$/.test(key) && root.settingDeclarationValid(settings[key]))
                normalized[key] = settings[key];
        }
        return normalized;
    }

    // Exact type match plus every declared constraint. This is the
    // one QML value check: the PluginKit Settings facade layers it
    // (via settingConstraintsSatisfied) on its own type check, and
    // the generated settings UI calls it directly.
    function settingValueValid(declaration: var, value: var): bool {
        if (!declaration || typeof declaration !== "object")
            return false;
        if (declaration.type === "boolean")
            return typeof value === "boolean";
        if (declaration.type === "integer") {
            if (typeof value !== "number" || !Number.isInteger(value))
                return false;
        } else if (declaration.type === "number") {
            if (typeof value !== "number" || !Number.isFinite(value))
                return false;
        } else if (declaration.type === "string") {
            // Count Unicode code points like JSON Schema/Python,
            // not UTF-16 code units (String.length).
            const length = typeof value === "string" ? [...value].length : -1;
            if (length < 0 || length > 4096)
                return false;
            if (typeof declaration.minLength === "number" && length < declaration.minLength)
                return false;
            if (typeof declaration.maxLength === "number" && length > declaration.maxLength)
                return false;
            return true;
        } else if (declaration.type === "enum") {
            return typeof value === "string" && Array.isArray(declaration.options) && declaration.options.includes(value);
        } else {
            return false;
        }
        if (typeof declaration.minimum === "number" && value < declaration.minimum)
            return false;
        if (typeof declaration.maximum === "number" && value > declaration.maximum)
            return false;
        return true;
    }

    // Constraint half of settingValueValid for callers that already
    // type-checked the value (PluginKit Settings.validValue).
    function settingConstraintsSatisfied(value: var, declaration: var): bool {
        return root.settingValueValid(declaration, value);
    }

    // Migration (shell#374): a stored value written under an older
    // manifest keeps working while it still satisfies the current
    // declaration; anything else (changed type, removed enum option,
    // tightened range/length, malformed shape) falls back to the
    // declared default — never coerced, never a crash.
    function migratedSettingValue(declaration: var, stored: var): var {
        return root.settingValueValid(declaration, stored) ? stored : declaration.default;
    }

    function markPlacement(id: string, placement: string, entrypoint: string, settings: var, surfaces: var): void {
        const current = root.entries.find(e => e.id === id);
        const normalized = root.normalizeSettings(settings);
        const normalizedSurfaces = root.normalizeSurfaces(surfaces, placement, entrypoint);
        if (current && current.placement === placement && current.entrypoint === entrypoint
                && JSON.stringify(current.settings || {}) === JSON.stringify(normalized)
                && JSON.stringify(current.surfaces || {}) === JSON.stringify(normalizedSurfaces))
            return;
        const next = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            placement: placement,
            entrypoint: entrypoint,
            surfaces: normalizedSurfaces,
            settings: normalized
        }) : e);
        root.entries = next;
    }

    function surfaceFor(entry: var, surface: string): var {
        if (!entry)
            return null;
        const surfaces = entry.surfaces && typeof entry.surfaces === "object" && !Array.isArray(entry.surfaces) ? entry.surfaces : null;
        if (surfaces) {
            const declared = surfaces[surface];
            return declared && typeof declared === "object" ? declared : null;
        }
        // Entries not yet visited by PluginHost have no surfaces map;
        // fall back to the v1 single placement/entrypoint pair.
        return entry.placement === surface && typeof entry.entrypoint === "string" && entry.entrypoint !== "" ? {
            entrypoint: entry.entrypoint,
            enabled: true
        } : null;
    }

    function hasPlacement(id: string, placement: string): bool {
        return root.hasSurface(id, placement);
    }

    function hasSurface(id: string, surface: string): bool {
        const entry = root.entries.find(e => e.id === id);
        const declared = root.surfaceFor(entry, surface);
        return !!entry && !!declared && declared.enabled !== false && entry.enabled && entry.installed;
    }

    // Host view of one surface: enabled, installed entries that
    // declare it, each copied with `entrypoint` set to that surface's
    // file (and `surface` naming it), so existing hosts keep loading
    // `modelData.entrypoint` exactly as they did for single-surface
    // manifests. A surface with enabled === false is skipped without
    // affecting the package's other surfaces.
    function pluginsForSurface(surface: string): var {
        const result = [];
        for (const entry of root.entries) {
            if (!entry.enabled || !entry.installed)
                continue;
            const declared = root.surfaceFor(entry, surface);
            if (!declared || declared.enabled === false || typeof declared.entrypoint !== "string" || declared.entrypoint === "")
                continue;
            result.push(Object.assign({}, entry, {
                entrypoint: declared.entrypoint,
                surface: surface
            }));
        }
        return result;
    }

    // Plugin translations (shell#375): PluginHost records the
    // manifest `translations` declaration here exactly as validated;
    // PluginKit Translations reads it back by plugin id. Recording a
    // declaration grants nothing — catalogs are package files the
    // entrypoint could read anyway; this only gives PluginKit one
    // canonical place to learn which locales the package ships.
    function markTranslations(id: string, translations: var): void {
        const normalized = root.normalizeTranslations(translations);
        const current = root.entries.find(e => e.id === id);
        if (current && JSON.stringify(current.translations || null) === JSON.stringify(normalized))
            return;
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            translations: normalized
        }) : e);
    }

    // Keep only the validated shape: a sourceLocale string, a list of
    // locale tag strings, and an optional directory. Malformed shapes
    // were already rejected by PluginHost's runtime manifest gate, so
    // this is defence in depth, never a second parser with new rules.
    function normalizeTranslations(translations: var): var {
        if (!translations || typeof translations !== "object" || Array.isArray(translations))
            return null;
        const locales = Array.isArray(translations.locales) ? translations.locales.filter(l => typeof l === "string" && l !== "") : [];
        return {
            sourceLocale: typeof translations.sourceLocale === "string" && translations.sourceLocale !== "" ? translations.sourceLocale : "en",
            locales: locales,
            directory: typeof translations.directory === "string" && translations.directory !== "" ? translations.directory : "translations"
        };
    }

    function translationDeclaration(id: string): var {
        const entry = root.entries.find(e => e.id === id);
        if (!entry || !entry.translations || typeof entry.translations !== "object")
            return null;
        return entry.translations;
    }

    function settingDeclaration(id: string, key: string): var {
        const entry = root.entries.find(e => e.id === id);
        if (!entry || !entry.settings || typeof entry.settings !== "object")
            return null;

        const declaration = entry.settings[key];
        return declaration && typeof declaration === "object" ? declaration : null;
    }

    function barPlugins(): var {
        return root.pluginsForSurface("bar");
    }

    function dashboardPlugins(): var {
        return root.pluginsForSurface("dashboard");
    }

    function desktopPlugins(): var {
        return root.pluginsForSurface("desktop");
    }

    function backgroundPlugins(): var {
        return root.pluginsForSurface("background");
    }

    function markLoaded(id: string): void {
        root.setState(id, "loaded", "");
    }

    function markFailed(id: string, detail: string): void {
        root.setState(id, "failed", (detail ?? "").toString().slice(0, 200));
        console.warn(`[plugins] ${id} failed to load: ${detail}`);
    }

    function setState(id: string, state: string, detail: string): void {
        const current = root.entries.find(e => e.id === id);
        if (current && current.state === state && (current.detail || "") === detail)
            return;
        const next = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            state: state,
            detail: detail
        }) : e);
        root.entries = next;
    }

    function status(): var {
        return {
            discovered: root.discovered,
            loading: root.loading,
            discoveryError: root.discoveryError,
            pluginsDir: root.pluginsDir,
            count: root.entries.length,
            loaded: root.entries.filter(e => e.state === "loaded").length,
            failed: root.entries.filter(e => e.state === "failed").length,
            plugins: root.entries
        };
    }

    Process {
        id: listProcess

        command: ["horneroctl", "plugin", "list", "--json"]

        stdout: SplitParser {
            onRead: data => {
                root.buffer += data;
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.discoveryError = qsTr("horneroctl plugin list failed (exit %1)").arg(exitCode);
                root.discovered = true;
                return;
            }
            let parsed = [];
            try {
                const envelope = JSON.parse(root.buffer.trim());
                const raw = envelope && envelope.data ? envelope.data.plugins : null;
                const list = typeof raw === "string" ? JSON.parse(raw) : raw;
                if (!Array.isArray(list))
                    throw new Error("plugins payload is not a list");
                parsed = list;
            } catch (e) {
                root.discoveryError = qsTr("horneroctl plugin list returned malformed JSON");
                root.discovered = true;
                return;
            }
            root.entries = parsed.map(e => {
                const requestedEnabled = !!e.enabled && !!e.installed;
                const trusted = ["official", "trusted", "signed"].includes(e.trust);
                const enabled = requestedEnabled && trusted;
                return Object.assign({}, e, {
                    placement: typeof e.placement === "string" ? e.placement : "",
                    requestedEnabled: requestedEnabled,
                    enabled: enabled,
                    state: requestedEnabled && !trusted ? "blocked" : enabled ? "pending" : "disabled",
                    detail: requestedEnabled && !trusted
                        ? qsTr("This plugin is marked enabled, but its payload is not trusted. Review and trust it, then enable it again.")
                        : ""
                });
            });
            root.discovered = true;
        }
    }

    Component.onCompleted: reload()
}
