pragma Singleton

import "deck.js" as Deck
import qs.config
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Community plugin runtime state (M2). horneroctl is the single writer
// of lifecycle state (install/enable/disable/remove); this service only
// discovers what is enabled and tracks load outcomes for the host.
//
// Manifest v2 (shell#373): one package may declare several entry
// points in `surfaces` (background, bar, dashboard, desktop and
// settings — hosted in Control Center › Extensions — plus the
// launcher surface, hosted by PluginLauncherHost into the
// launcher provider registry).
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

    // Entries: {id, name, version, enabled, installed, state, detail,
    // loadStartedAtMs, loadMs, attempts, diagnostics}
    // state: pending | loaded | failed | disabled | safe-mode
    property var entries: []
    property bool discovered: false
    property string discoveryError: ""
    property string buffer: ""
    readonly property bool loading: listProcess.running

    // Diagnostics & safe recovery (shell#380). Safe mode is effective
    // when forced at launch (HORNERO_SAFE_MODE=1/true, read before any
    // plugin manifest exists in memory) or persisted in config. While
    // it is on, hosts receive no entries: no manifest is parsed and no
    // plugin QML is instantiated, so a malformed or crash-looping
    // plugin cannot block the (core, non-plugin) recovery UI in
    // Control Center › Extensions, where it can still be disabled via
    // horneroctl. Safe mode never writes lifecycle state itself.
    readonly property bool safeModeEnv: ["1", "true"].includes((Quickshell.env("HORNERO_SAFE_MODE") ?? "").toLowerCase())
    readonly property bool safeMode: root.safeModeEnv || Config.plugins.safeMode === true
    readonly property double startedAtMs: Date.now()
    // Performance budgets: advisory diagnostics only — exceeding one
    // is flagged in status/UI, never enforced by killing plugin QML
    // (in-process QML cannot be preempted; see trust label above).
    readonly property int slowLoadBudgetMs: 2000
    readonly property int churnAttemptBudget: 5
    readonly property int churnWindowMs: 60000
    // Bounded, secret-redacted event log: {atMs, id, event, detail}.
    property var diagnosticsLog: []

    // Desktop widget edit mode (PluginKit 3): while true, desktop widget
    // frames show move/resize handles and persist the person's geometry.
    // Session state, never persisted; entered from Control Center or
    // `qs ipc call plugins editDesktop`.
    property bool desktopEditing: false
    // Ids of enabled desktop widgets the solver could not place (no room);
    // reported by `plugins status`, never drawn overlapping another.
    property var desktopNoRoom: []

    // Loader error strings can embed URLs or argv a plugin built from
    // its own settings; redact credential-looking assignments before
    // anything is logged, stored, or shown.
    function sanitizeDetail(detail: var): string {
        return (detail ?? "").toString()
            .replace(/(token|password|passwd|secret|api[_-]?key|authorization)(\s*[=:]\s*)\S+/gi, "$1$2<redacted>")
            .replace(/Bearer\s+\S+/gi, "Bearer <redacted>")
            .slice(0, 200);
    }

    function logDiagnostic(id: string, event: string, detail: string): void {
        const next = root.diagnosticsLog.concat([{
            atMs: Date.now(),
            id: id,
            event: event,
            detail: root.sanitizeDetail(detail)
        }]);
        root.diagnosticsLog = next.slice(-50);
    }

    function diagnosticsFor(id: string): var {
        return root.diagnosticsLog.filter(entry => entry.id === id);
    }

    // Excessive reload/poll churn visible to the host: load attempts
    // inside the churn window. Plugin-internal Timers are not
    // observable in-process; scripts/validate_plugin.py flags
    // sub-second literal Timer intervals statically instead.
    function attemptDiagnostics(entry: var, loadMs: int): var {
        const codes = [];
        if (loadMs > root.slowLoadBudgetMs)
            codes.push("slow-load");
        const now = Date.now();
        const recent = (entry.attemptTimesMs || []).filter(at => now - at < root.churnWindowMs);
        if (recent.length >= root.churnAttemptBudget)
            codes.push("load-churn");
        return codes;
    }

    readonly property string pluginsDir: `${Paths.data}/plugins`

    // PluginKit version gate. PluginHost reports the apiLevel of the
    // Hornero.PluginKit module the shell actually resolved (0 when it
    // predates the PluginKitInfo marker, -1 until probed). Manifests are
    // schemaVersion 3, so every extension needs a kit of at least
    // requiredKitLevel; a stale kit left on the QML import path by a
    // partial upgrade would otherwise fail each extension with raw QML
    // noise ("UiTextField is not a type"). While the kit is too old no
    // extension is hosted and each enabled one says so plainly.
    readonly property int requiredKitLevel: 3
    property int kitLevel: -1
    readonly property bool kitBlocked: root.kitLevel >= 0 && root.kitLevel < root.requiredKitLevel
    readonly property string kitMessage: root.kitBlocked
        ? qsTr("The installed PluginKit is too old (API level %1, this Shell needs %2). Update the hornero-shell package or point QML2_IMPORT_PATH at this Shell's plugin/qml. Extensions are not loaded until then.").arg(root.kitLevel).arg(root.requiredKitLevel)
        : ""
    // Hosts must not instantiate anything in safe mode or on a stale kit.
    readonly property bool hostingBlocked: root.safeMode || root.kitBlocked

    onKitBlockedChanged: root.applyKitGate()

    // Toggling safe mode live: hosts empty at once, so report it instead of
    // leaving stale "loaded" states, and rediscover when it is turned off.
    onSafeModeChanged: {
        if (root.safeMode)
            root.entries = root.entries.map(e => e.enabled && e.installed ? Object.assign({}, e, {
                state: "safe-mode",
                detail: qsTr("Safe mode is on: this plugin was not loaded. Disable it here, or turn safe mode off to load plugins again.")
            }) : e);
        else if (root.discovered)
            root.reload();
    }

    function applyKitGate(): void {
        if (!root.kitBlocked)
            return;
        console.warn(`[plugins] ${root.kitMessage}`);
        root.entries = root.entries.map(e => e.enabled && e.installed ? Object.assign({}, e, {
            state: "failed",
            detail: root.kitMessage
        }) : e);
    }

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
                        && typeof surface.entrypoint === "string" && surface.entrypoint !== "") {
                    normalized[name] = {
                        entrypoint: surface.entrypoint,
                        enabled: surface.enabled !== false
                    };
                    // Dashboard card hints (shell#378): keep only
                    // validated values; anything else degrades to the
                    // standard/uncategorized defaults at the host.
                    if (name === "bar" && ["status", "actions", "clock", "end"].includes(surface.section))
                        normalized[name].section = surface.section;
                    // Desktop widget hints (PluginKit 3): geometry
                    // defaults the desktop host starts from.
                    if (name === "desktop") {
                        for (const key of ["width", "height", "minWidth", "minHeight"]) {
                            if (Number.isInteger(surface[key]) && surface[key] >= 80 && surface[key] <= 1600)
                                normalized[name][key] = surface[key];
                        }
                        if (typeof surface.resizable === "boolean")
                            normalized[name].resizable = surface.resizable;
                        if (typeof surface.anchor === "string")
                            normalized[name].anchor = surface.anchor;
                    }
                    if (name === "dashboard") {
                        if (["compact", "standard", "wide"].includes(surface.size))
                            normalized[name].size = surface.size;
                        if (typeof surface.category === "string" && /\S/.test(surface.category) && surface.category.length <= 40
                                && surface.category.trim().toLowerCase() !== "pinned")
                            normalized[name].category = surface.category;
                    }
                }
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
        // PluginKit 4 adds colour, list, text and path plus the
        // display-only fields title, group, unit, step, visibleWhen
        // (RFC 0003 section 5). `pluginKit` level gating happens in the
        // validator and the host; the normaliser accepts what the
        // validator accepts.
        const allowed = {
            boolean: [],
            integer: ["minimum", "maximum", "step", "unit"],
            number: ["minimum", "maximum", "step", "unit"],
            string: ["minLength", "maxLength"],
            enum: ["options"],
            colour: ["alpha"],
            list: ["options", "minItems", "maxItems"],
            text: ["minLength", "maxLength", "rows"],
            path: ["kind", "mustExist"]
        };
        if (!Object.prototype.hasOwnProperty.call(allowed, declaration.type))
            return false;
        const keys = Object.keys(declaration);
        const known = ["type", "default", "description", "title", "group", "visibleWhen"].concat(allowed[declaration.type]);
        if (!keys.every(key => known.includes(key)) || !keys.includes("default"))
            return false;
        if (declaration.description !== undefined
                && (typeof declaration.description !== "string" || declaration.description.length > 160
                    || !/\S/.test(declaration.description)))
            return false;
        for (const [field, limit] of [["title", 48], ["group", 32], ["unit", 8]]) {
            if (declaration[field] !== undefined
                    && (typeof declaration[field] !== "string" || declaration[field].length > limit
                        || !/\S/.test(declaration[field])))
                return false;
        }
        if (declaration.visibleWhen !== undefined) {
            const condition = declaration.visibleWhen;
            if (!condition || typeof condition !== "object" || Array.isArray(condition)
                    || Object.keys(condition).length !== 2 || typeof condition.key !== "string"
                    || !Object.prototype.hasOwnProperty.call(condition, "equals"))
                return false;
        }
        if (declaration.step !== undefined
                && (typeof declaration.step !== "number" || !Number.isFinite(declaration.step) || declaration.step <= 0
                    || (declaration.type === "integer" && !Number.isInteger(declaration.step))))
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
        if (declaration.type === "string" || declaration.type === "text") {
            for (const bound of ["minLength", "maxLength"]) {
                const limit = declaration[bound];
                if (limit !== undefined && (typeof limit !== "number" || !Number.isInteger(limit) || limit < 0 || limit > 4096))
                    return false;
            }
            if (declaration.minLength !== undefined && declaration.maxLength !== undefined
                    && declaration.minLength > declaration.maxLength)
                return false;
        }
        if (declaration.type === "text" && declaration.rows !== undefined
                && (!Number.isInteger(declaration.rows) || declaration.rows < 1 || declaration.rows > 12))
            return false;
        if (declaration.type === "enum" || declaration.type === "list") {
            const options = declaration.options;
            if (!Array.isArray(options) || options.length === 0 || options.length > 32
                    || options.some(option => typeof option !== "string" || option === "" || option.length > 64)
                    || new Set(options).size !== options.length)
                return false;
        }
        if (declaration.type === "list") {
            for (const bound of ["minItems", "maxItems"]) {
                const limit = declaration[bound];
                if (limit !== undefined && (!Number.isInteger(limit) || limit < 0 || limit > declaration.options.length))
                    return false;
            }
            if (declaration.minItems !== undefined && declaration.maxItems !== undefined
                    && declaration.minItems > declaration.maxItems)
                return false;
        }
        if (declaration.type === "colour" && declaration.alpha !== undefined && typeof declaration.alpha !== "boolean")
            return false;
        if (declaration.type === "path") {
            if (declaration.kind !== undefined && !["file", "directory"].includes(declaration.kind))
                return false;
            if (declaration.mustExist !== undefined && typeof declaration.mustExist !== "boolean")
                return false;
            const fallback = declaration.default;
            if (typeof fallback === "string" && fallback !== ""
                    && (fallback.startsWith("/") || fallback.startsWith("~") || fallback.includes("\\")
                        || fallback.split("/").includes("..")))
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
        } else if (declaration.type === "string" || declaration.type === "text") {
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
        } else if (declaration.type === "colour") {
            return typeof value === "string" && (declaration.alpha === true ? /^#[0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?$/ : /^#[0-9a-fA-F]{6}$/).test(value);
        } else if (declaration.type === "list") {
            const options = Array.isArray(declaration.options) ? declaration.options : [];
            if (!Array.isArray(value) || new Set(value).size !== value.length
                    || value.some(item => typeof item !== "string" || !options.includes(item)))
                return false;
            const most = typeof declaration.maxItems === "number" ? declaration.maxItems : options.length;
            const least = typeof declaration.minItems === "number" ? declaration.minItems : 0;
            return value.length >= least && value.length <= most;
        } else if (declaration.type === "path") {
            return typeof value === "string" && value.length <= 1024 && !/[\u0000-\u001f\u007f]/.test(value);
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

    // Manifest description for the Extensions pane cards (shell#470):
    // plain text, single spaces, at most 400 characters; anything else is
    // dropped. Unchanged values do not reassign entries.
    function normalizeDescription(description: var): string {
        if (typeof description !== "string")
            return "";
        const text = description.replace(/\s+/g, " ").trim();
        return text.length > 0 && text.length <= 400 ? text : "";
    }

    // Manifest schemaVersion as the host read it (the Extensions pane
    // shows the PluginKit chip from it; horneroctl's list JSON omits it).
    function markSchemaVersion(id: string, version: var): void {
        const current = root.entries.find(e => e.id === id);
        if (!current || current.schemaVersion === version || !Number.isInteger(version))
            return;
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            schemaVersion: version
        }) : e);
    }

    function markDescription(id: string, description: var): void {
        const text = root.normalizeDescription(description);
        const current = root.entries.find(e => e.id === id);
        if (!current || (current.description || "") === text)
            return;
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            description: text
        }) : e);
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

    // Entrypoint URL with the package version as a cache key: QML caches a
    // compiled component per URL, so after `horneroctl plugin catalog
    // update` a running shell would keep the old code until restart. A new
    // version changes the URL, the host rebuilds the Loader (the version is
    // part of the StableList structure) and the new file is compiled. Only
    // the entrypoint is keyed; a same-version edit needs a restart.
    function entrypointUrl(id: string, entrypoint: string): string {
        const entry = root.entries.find(e => e.id === id);
        const version = entry && typeof entry.version === "string" ? entry.version : "";
        return `file://${root.pluginsDir}/${id}/${entrypoint}` + (version !== "" ? `?v=${encodeURIComponent(version)}` : "");
    }

    // Live entry for one id (state, detail, trust, ...). Delegates built
    // from a StableList read volatile fields here, never from modelData.
    function entryFor(id: string): var {
        return root.entries.find(e => e.id === id) ?? null;
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
        if (root.hostingBlocked)
            return false;
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
        if (root.hostingBlocked)
            return [];
        const result = [];
        for (const entry of root.entries) {
            if (!entry.enabled || !entry.installed)
                continue;
            const declared = root.surfaceFor(entry, surface);
            if (!declared || declared.enabled === false || typeof declared.entrypoint !== "string" || declared.entrypoint === "")
                continue;
            result.push(Object.assign({}, entry, {
                entrypoint: declared.entrypoint,
                surface: surface,
                // Dashboard card hints (shell#378): host copies carry
                // the declared size class/category so the dashboard
                // layout never re-reads the surfaces map per card.
                cardSize: typeof declared.size === "string" ? declared.size : "standard",
                category: typeof declared.category === "string" ? declared.category : "",
                // Bar section hint (shell#439): native island to join.
                barSection: typeof declared.section === "string" ? declared.section : "end"
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

    // Marketplace metadata (shell#379): static discovery/detail data
    // — screenshots, compatibility, changelog, deprecation — the
    // Extensions pane renders WITHOUT executing plugin code.
    // PluginHost records the manifest declaration here for every
    // installed package (enabled or not, via a manifest-only read);
    // entries may also arrive with it from horneroctl list/catalog
    // JSON, normalized on read below. Recording it grants nothing:
    // install/update/rollback stay on the existing verified
    // provenance contracts (shell#251/#366).
    function markMarketplace(id: string, marketplace: var): void {
        const normalized = root.normalizeMarketplace(marketplace);
        const current = root.entries.find(e => e.id === id);
        if (current && JSON.stringify(current.marketplace || null) === JSON.stringify(normalized))
            return;
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            marketplace: normalized
        }) : e);
    }

    // Keep only the validated shape, mirroring
    // scripts/validate_plugin.py: screenshot paths are safe relative
    // static-image files (.png/.jpg/.jpeg/.webp — never .qml/.svg,
    // so a preview can never execute or be interpreted as code),
    // compatibility bounds are semver strings, changelog entries are
    // {version, notes} with unique semver versions, and deprecation
    // keeps an optional message / replacedBy plugin id. Malformed
    // parts are dropped; nothing valid left means null, which
    // renders exactly like a pre-#379 manifest. Defence in depth:
    // installed manifests were already validated strictly.
    function normalizeMarketplace(marketplace: var): var {
        if (!marketplace || typeof marketplace !== "object" || Array.isArray(marketplace))
            return null;
        const semver = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/;
        const normalized = ({});
        if (Array.isArray(marketplace.screenshots)) {
            const shots = [];
            const seen = new Set();
            for (const shot of marketplace.screenshots) {
                if (shots.length >= 6)
                    break;
                if (!shot || typeof shot !== "object" || Array.isArray(shot)
                        || typeof shot.path !== "string"
                        || !/^(?!\/)(?!\.{1,2}(\/|$))(?!.*\/\.{1,2}(\/|$))(?!.*\/\/)[A-Za-z0-9._\/-]+\.(?:png|jpg|jpeg|webp)$/i.test(shot.path)
                        || shot.path.length > 240 || seen.has(shot.path))
                    continue;
                seen.add(shot.path);
                const entry = {
                    path: shot.path
                };
                if (typeof shot.alt === "string" && /\S/.test(shot.alt) && shot.alt.length <= 160)
                    entry.alt = shot.alt;
                shots.push(entry);
            }
            if (shots.length > 0)
                normalized.screenshots = shots;
        }
        const compatibility = marketplace.compatibility;
        if (compatibility && typeof compatibility === "object" && !Array.isArray(compatibility)) {
            const compat = ({});
            for (const bound of ["minShellVersion", "maxShellVersion"]) {
                if (typeof compatibility[bound] === "string" && semver.test(compatibility[bound]))
                    compat[bound] = compatibility[bound];
            }
            if (Object.keys(compat).length > 0)
                normalized.compatibility = compat;
        }
        if (Array.isArray(marketplace.changelog)) {
            const entries = [];
            const seenVersions = new Set();
            for (const item of marketplace.changelog) {
                if (entries.length >= 20)
                    break;
                if (!item || typeof item !== "object" || Array.isArray(item)
                        || typeof item.version !== "string" || !semver.test(item.version)
                        || seenVersions.has(item.version)
                        || typeof item.notes !== "string" || !/\S/.test(item.notes)
                        || item.notes.length > 1000)
                    continue;
                seenVersions.add(item.version);
                entries.push({
                    version: item.version,
                    notes: item.notes
                });
            }
            if (entries.length > 0)
                normalized.changelog = entries;
        }
        const deprecation = marketplace.deprecation;
        if (deprecation && typeof deprecation === "object" && !Array.isArray(deprecation)) {
            const deprecated = ({});
            if (typeof deprecation.message === "string" && /\S/.test(deprecation.message) && deprecation.message.length <= 280)
                deprecated.message = deprecation.message;
            if (typeof deprecation.replacedBy === "string" && /^[a-z0-9][a-z0-9-]{0,47}$/.test(deprecation.replacedBy))
                deprecated.replacedBy = deprecation.replacedBy;
            // Presence alone means deprecated, even with no detail.
            normalized.deprecation = deprecated;
        }
        return Object.keys(normalized).length > 0 ? normalized : null;
    }

    function marketplaceFor(id: string): var {
        const entry = root.entries.find(e => e.id === id);
        if (!entry || !entry.marketplace || typeof entry.marketplace !== "object")
            return null;
        return entry.marketplace;
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

    // Signal instrument deck (services/deck.js): the curated first-party
    // instruments, in catalogue order. Unlike desktopPlugins() they need
    // not be enabled in Extensions: an installed package whose payload is
    // trusted loads for the deck only (the person keeps the per-mode
    // off switch, and Extensions state is never written). Missing,
    // untrusted or safe-mode entries are simply absent here and are
    // reported by deckAvailability().
    function deckEligible(entry: var): bool {
        return !!entry && !root.hostingBlocked && !!entry.installed && ["official", "trusted", "signed"].includes(entry.trust) && !!root.surfaceFor(entry, "desktop");
    }

    function deckPlugins(): var {
        const result = [];
        for (const id of Deck.ids()) {
            const entry = root.entries.find(e => e.id === id);
            if (!root.deckEligible(entry))
                continue;
            const declared = root.surfaceFor(entry, "desktop");
            if (declared.enabled === false || typeof declared.entrypoint !== "string" || declared.entrypoint === "")
                continue;
            result.push(Object.assign({}, entry, {
                entrypoint: declared.entrypoint,
                surface: "desktop",
                deck: true
            }));
        }
        return result;
    }

    // id -> ready | not-installed | untrusted | failed, for Deck.status().
    function deckAvailability(): var {
        const out = ({});
        for (const id of Deck.ids()) {
            const entry = root.entries.find(e => e.id === id);
            if (root.safeMode)
                out[id] = "safe-mode";
            else if (root.kitBlocked)
                out[id] = "kit-too-old";
            else if (!entry || !entry.installed)
                out[id] = "not-installed";
            else if (!["official", "trusted", "signed"].includes(entry.trust))
                out[id] = "untrusted";
            else if (!root.surfaceFor(entry, "desktop"))
                out[id] = "not-installed";
            else
                out[id] = entry.state === "failed" ? "failed" : "ready";
        }
        return out;
    }

    function setDesktopEditing(editing: bool): void {
        root.desktopEditing = editing && !root.safeMode;
    }

    function backgroundPlugins(): var {
        return root.pluginsForSurface("background");
    }

    function settingsPlugins(): var {
        return root.pluginsForSurface("settings");
    }

    function launcherPlugins(): var {
        return root.pluginsForSurface("launcher");
    }

    // Effective `settings` surface for one entry, or null: enabled,
    // installed, surface enabled, a non-empty entrypoint, and never
    // in safe mode. The Control Center host gates on this, so a
    // disabled (or safe-mode) plugin's custom settings UI is never
    // loaded and an already-loaded one unloads.
    function settingsSurfaceFor(entry: var): var {
        if (!entry || root.hostingBlocked || !entry.enabled || !entry.installed)
            return null;
        const declared = root.surfaceFor(entry, "settings");
        if (!declared || declared.enabled === false || typeof declared.entrypoint !== "string" || declared.entrypoint === "")
            return null;
        return declared;
    }

    function hasSettingsSurface(entry: var): bool {
        return root.settingsSurfaceFor(entry) !== null;
    }

    // Native bar popouts for extensions (shell#449): an extension asks for
    // its popout (click/keyboard); the bar that owns the requesting host
    // Loader opens or closes it in its shared popout panel.
    signal popoutRequested(Item loader, bool open)

    function requestPopout(loader: Item, open: bool): void {
        if (loader)
            root.popoutRequested(loader, open);
    }

    // Load outcomes are tracked per surface: a package with several entry
    // points is `failed` while ANY of them failed (the last host to report
    // used to win, so a healthy bar indicator hid a broken launcher surface).
    // `surface` is "" for the primary/background entrypoint.
    function markLoading(id: string): void {
        const current = root.entries.find(e => e.id === id);
        if (!current || current.hostLoadStartedAtMs > 0 && current.hostLoadStartedAtMs >= (current.loadStartedAtMs || 0))
            return;
        // Honest timing: measured from the moment a host starts
        // instantiating the entrypoint, not from discovery (a dashboard
        // card that is only built when its tab opens is not "slow").
        const now = Date.now();
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            hostLoadStartedAtMs: now
        }) : e);
    }

    function markLoaded(id: string, surface: var): void {
        const key = typeof surface === "string" && surface !== "" ? surface : "main";
        const current = root.entries.find(e => e.id === id);
        const failed = Object.assign({}, current ? current.failedSurfaces : null);
        delete failed[key];
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            failedSurfaces: failed
        }) : e);
        const remaining = Object.keys(failed);
        if (remaining.length > 0) {
            root.setState(id, "failed", failed[remaining[0]]);
            return;
        }
        root.setState(id, "loaded", "");
        root.logDiagnostic(id, "loaded", typeof surface === "string" ? surface : "");
    }

    function markFailed(id: string, detail: var, surface: var): void {
        const clean = root.sanitizeDetail(detail);
        const named = typeof surface === "string" && surface !== "";
        const key = named ? surface : "main";
        const current = root.entries.find(e => e.id === id);
        const failed = Object.assign({}, current ? current.failedSurfaces : null);
        failed[key] = clean;
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            failedSurfaces: failed
        }) : e);
        root.setState(id, "failed", clean);
        root.logDiagnostic(id, "failed", named ? `${surface}: ${clean}` : clean);
        console.warn(`[plugins] ${id} failed to load${named ? ` (${surface})` : ""}: ${clean}`);
    }

    // Loader.errorString is empty for asynchronous loads, so failures used
    // to read "failed to load (see shell log)". Compiling the same URL
    // synchronously yields the real QML error (missing type, syntax, ...),
    // with the plugin's own directory stripped from the path.
    function loaderError(errorString: var, source: var): string {
        // Quickshell/QtQuick Loader has no errorString property, so hosts
        // pass undefined here; a typed string parameter would turn that
        // into the literal text "undefined".
        let text = typeof errorString === "string" ? errorString : "";
        const url = (source ?? "").toString();
        if (text === "" && url !== "") {
            try {
                const component = Qt.createComponent(url, Component.PreferSynchronous);
                text = component.errorString();
                component.destroy();
            } catch (e) {
                text = "";
            }
        }
        return text.split(`file://${root.pluginsDir}/`).join("").replace(/\?v=[^:\s]*/g, "").replace(/\s+/g, " ").trim();
    }

    // Per-extension reload (shell#380): reset one entry to pending
    // with a fresh load clock; reassigning entries makes every host
    // re-instantiate its Loader for that id. Unknown/disabled ids are
    // a no-op, and safe mode reloads nothing (hosts stay empty).
    function reloadPlugin(id: string): bool {
        const current = root.entries.find(e => e.id === id);
        if (!current || !current.enabled || !current.installed || root.safeMode)
            return false;
        const now = Date.now();
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            state: "pending",
            detail: "",
            failedSurfaces: ({}),
            loadMs: -1,
            loadStartedAtMs: now,
            attempts: (e.attempts || 0) + 1,
            attemptTimesMs: (e.attemptTimesMs || []).concat([now]).slice(-20)
        }) : e);
        root.logDiagnostic(id, "reload", "");
        return true;
    }

    function setState(id: string, state: string, detail: string): void {
        const current = root.entries.find(e => e.id === id);
        if (current && current.state === state && (current.detail || "") === detail)
            return;
        const now = Date.now();
        const next = root.entries.map(e => {
            if (e.id !== id)
                return e;
            const startedAt = (e.hostLoadStartedAtMs || 0) >= (e.loadStartedAtMs || 0) && (e.hostLoadStartedAtMs || 0) > 0 ? e.hostLoadStartedAtMs : (e.loadStartedAtMs || root.startedAtMs);
            const loadMs = Math.max(0, Math.round(now - startedAt));
            return Object.assign({}, e, {
                state: state,
                detail: detail,
                loadMs: loadMs,
                lastStateAtMs: now,
                diagnostics: root.attemptDiagnostics(e, loadMs)
            });
        });
        root.entries = next;
    }

    function status(): var {
        return {
            discovered: root.discovered,
            loading: root.loading,
            discoveryError: root.discoveryError,
            pluginsDir: root.pluginsDir,
            safeMode: root.safeMode,
            safeModeEnv: root.safeModeEnv,
            kit: {
                level: root.kitLevel,
                required: root.requiredKitLevel,
                compatible: !root.kitBlocked,
                message: root.kitMessage
            },
            budgets: {
                slowLoadMs: root.slowLoadBudgetMs,
                churnAttempts: root.churnAttemptBudget,
                churnWindowMs: root.churnWindowMs
            },
            diagnosticsLog: root.diagnosticsLog,
            desktopNoRoom: root.desktopNoRoom,
            count: root.entries.length,
            loaded: root.entries.filter(e => e.state === "loaded").length,
            failed: root.entries.filter(e => e.state === "failed").length,
            plugins: root.entries.map(e => e.state === "pending" && !(e.hostLoadStartedAtMs > 0) ? Object.assign({}, e, {
                instantiated: false,
                detail: e.detail || qsTr("Not instantiated yet: this surface is built when it is shown (a dashboard card when the Extensions tab opens).")
            }) : Object.assign({}, e, {
                instantiated: e.state !== "disabled"
            }))
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
            const discoveredAtMs = Date.now();
            const previousById = ({});
            for (const prior of root.entries)
                previousById[prior.id] = prior;
            root.entries = parsed.map(e => {
                const requestedEnabled = !!e.enabled && !!e.installed;
                const trusted = ["official", "trusted", "signed"].includes(e.trust);
                const enabled = requestedEnabled && trusted;
                const prior = previousById[e.id] || {};
                const priorAttempts = typeof prior.attempts === "number" ? prior.attempts : 0;
                const priorTimes = Array.isArray(prior.attemptTimesMs) ? prior.attemptTimesMs : [];
                return Object.assign({}, e, {
                    // Marketplace metadata may ride the list JSON
                    // (shell#379); sanitize it here so the pane only
                    // ever renders the validated static shape.
                    marketplace: root.normalizeMarketplace(e.marketplace),
                    placement: typeof e.placement === "string" ? e.placement : "",
                    requestedEnabled: requestedEnabled,
                    enabled: enabled,
                    state: enabled && root.safeMode ? "safe-mode" : requestedEnabled && !trusted ? "blocked" : enabled ? "pending" : "disabled",
                    detail: enabled && root.safeMode
                        ? qsTr("Safe mode is on: this plugin was not loaded. Disable it here, or turn safe mode off to load plugins again.")
                        : requestedEnabled && !trusted
                        ? qsTr("This plugin is marked enabled, but its payload is not trusted. Review and trust it, then enable it again.")
                        : "",
                    loadStartedAtMs: discoveredAtMs,
                    loadMs: -1,
                    attempts: enabled ? priorAttempts + 1 : priorAttempts,
                    attemptTimesMs: enabled ? priorTimes.concat([discoveredAtMs]).slice(-20) : priorTimes,
                    diagnostics: []
                });
            });
            root.discovered = true;
            root.applyKitGate();
        }
    }

    Component.onCompleted: reload()
}
