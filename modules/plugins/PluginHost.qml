pragma ComponentBehavior: Bound

import qs.services
import qs.utils
import Quickshell
import Quickshell.Io
import QtQuick

// Plugin runtime host (M2 slice 1): loads every enabled, installed
// community plugin entrypoint exactly once per discovery, each in its
// own Loader so a plugin that fails to compile or instantiate is
// marked failed and never takes the shell (or other plugins) down.
//
// Slice 1 is headless for `background` plugins (the default):
// entrypoints are instantiated under an invisible root. Plugins whose
// manifest declares `placement: "bar"` are not loaded here; the bar
// renders them in its end group (modules/plugins/PluginBarWidgets.qml
// via modules/bar/Bar.qml). `placement: "dashboard"` plugins are
// rendered as cards by the dashboard Extensions tab
// (modules/plugins/PluginDashboardCards.qml); desktop plugins are
// placed by modules/plugins/PluginDesktopWidgets.qml. Unknown
// placements are rejected.
//
// Manifest v2 (shell#373): `surfaces` may add entry points on other
// surfaces, each independently enabled. This host validates the
// manifest, records the effective surfaces map in the Plugins
// service, and itself loads only the effective `background` surface
// (the headless one); the bar/dashboard/desktop hosts load theirs
// from the service's per-surface lists. `settings` is hosted by
// Control Center › Extensions (PluginSettingsHost.qml), not
// here; `launcher` is a validated declaration with no host yet —
// nothing loads it here. A v1 manifest derives the single
// placement surface and loads exactly as before.
// Plugin QML runs with full user privileges — see services/Plugins.qml
// for the trust label.
Scope {
    id: root

    // A Repeater placed directly under a Scope (a non-visual QObject)
    // never materialises its delegates: they are counted but their
    // components never complete, so manifests were never read and every
    // plugin stayed "pending" forever. The invisible Item root gives the
    // delegates a real parent so they instantiate; `background`
    // entrypoints load under it, still invisible by design.
    Item {
        visible: false

    Repeater {
        // Safe mode (shell#380): no delegate, so no manifest is even
        // read — a malformed plugin cannot block recovery access.
        model: Plugins.safeMode ? [] : Plugins.entries.filter(e => e.enabled && e.installed)

        delegate: Item {
            id: slot

            required property var modelData
            readonly property string pluginDir: `${Plugins.pluginsDir}/${modelData.id}`
            property string entrypoint: ""
            property string placement: ""
            // Effective background-surface file ("" when the package
            // has no enabled background surface); the only entrypoint
            // this headless host loads. For a v1 manifest this is the
            // top-level entrypoint exactly when placement is
            // background, matching the pre-v2 behaviour.
            property string backgroundEntrypoint: ""

            FileView {
                id: manifestView

                path: `${slot.pluginDir}/manifest.json`
                printErrors: false

                onLoaded: {
                    try {
                        const manifest = JSON.parse(manifestView.text());
                        if (manifest.id !== slot.modelData.id) {
                            Plugins.markFailed(slot.modelData.id, "manifest id does not match its directory");
                            return;
                        }
                        if (manifest.schemaVersion !== 1 && manifest.schemaVersion !== 2) {
                            Plugins.markFailed(slot.modelData.id, "manifest schemaVersion must be 1 or 2 (unknown manifest versions are rejected)");
                            return;
                        }
                        if (typeof manifest.version !== "string" || !/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/.test(manifest.version)) {
                            Plugins.markFailed(slot.modelData.id, "manifest version must be semantic versioning");
                            return;
                        }
                        if (typeof manifest.entrypoint !== "string" || manifest.entrypoint.includes("..") || manifest.entrypoint.includes("\\")
                                || !/^(?!\/)(?!\.{1,2}(\/|$))(?!.*\/\.{1,2}(\/|$))(?!.*\/\/)[A-Za-z0-9._\/-]+\.qml$/.test(manifest.entrypoint)) {
                            Plugins.markFailed(slot.modelData.id, "manifest entrypoint is not a safe relative path");
                            return;
                        }
                        if (!Array.isArray(manifest.files) || !manifest.files.includes(manifest.entrypoint)) {
                            Plugins.markFailed(slot.modelData.id, "manifest files must list the entrypoint");
                            return;
                        }
                        const placement = typeof manifest.placement === "string" ? manifest.placement : "background";
                        if (placement !== "background" && placement !== "bar" && placement !== "dashboard" && placement !== "desktop") {
                            Plugins.markFailed(slot.modelData.id, "manifest placement must be background, bar, dashboard or desktop");
                            return;
                        }
                        // Manifest v2 surfaces: strict runtime gate
                        // mirroring scripts/validate_plugin.py, with
                        // actionable failures. Only the six known
                        // surfaces are accepted, each entrypoint must
                        // be a safe relative .qml listed in files, and
                        // redeclaring the primary placement with a
                        // different file is a conflict, not an override.
                        const knownSurfaces = ["background", "bar", "dashboard", "desktop", "launcher", "settings"];
                        const safeEntrypoint = value => typeof value === "string" && !value.includes("..") && !value.includes("\\")
                            && /^(?!\/)(?!\.{1,2}(\/|$))(?!.*\/\.{1,2}(\/|$))(?!.*\/\/)[A-Za-z0-9._\/-]+\.qml$/.test(value);
                        const effectiveSurfaces = ({});
                        effectiveSurfaces[placement] = {
                            entrypoint: manifest.entrypoint,
                            enabled: true
                        };
                        if (manifest.surfaces !== undefined) {
                            if (manifest.schemaVersion !== 2) {
                                Plugins.markFailed(slot.modelData.id, "manifest surfaces requires schemaVersion 2");
                                return;
                            }
                            if (!manifest.surfaces || typeof manifest.surfaces !== "object" || Array.isArray(manifest.surfaces)
                                    || Object.keys(manifest.surfaces).length === 0) {
                                Plugins.markFailed(slot.modelData.id, "manifest surfaces must be a non-empty object");
                                return;
                            }
                            for (const name of Object.keys(manifest.surfaces)) {
                                if (!knownSurfaces.includes(name)) {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces contains unknown surface "${name}"`);
                                    return;
                                }
                                const surface = manifest.surfaces[name];
                                if (!surface || typeof surface !== "object" || Array.isArray(surface)) {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces.${name} must be an object`);
                                    return;
                                }
                                const extra = Object.keys(surface).filter(key => key !== "entrypoint" && key !== "enabled" && key !== "size" && key !== "category");
                                if (extra.length > 0) {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces.${name} contains unknown fields: ${extra.join(", ")}`);
                                    return;
                                }
                                // Dashboard card hints (shell#378),
                                // mirroring validate_plugin.py: size is
                                // a closed class set, category a short
                                // grouping label, both dashboard-only.
                                if ((surface.size !== undefined || surface.category !== undefined) && name !== "dashboard") {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces.${name}.size/category are dashboard card hints and are only allowed on the dashboard surface`);
                                    return;
                                }
                                if (surface.size !== undefined && !["compact", "standard", "wide"].includes(surface.size)) {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces.${name}.size must be one of compact, standard, wide`);
                                    return;
                                }
                                if (surface.category !== undefined
                                        && (typeof surface.category !== "string" || !/\S/.test(surface.category)
                                            || surface.category.length > 40
                                            || surface.category.trim().toLowerCase() === "pinned")) {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces.${name}.category must be a non-empty grouping label of at most 40 characters (and not the reserved "Pinned" section)`);
                                    return;
                                }
                                if (!safeEntrypoint(surface.entrypoint)) {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces.${name}.entrypoint is not a safe relative path`);
                                    return;
                                }
                                if (!manifest.files.includes(surface.entrypoint)) {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces.${name}.entrypoint must be listed in files`);
                                    return;
                                }
                                if (name === placement && surface.entrypoint !== manifest.entrypoint) {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces.${name}.entrypoint conflicts with the top-level entrypoint for the primary placement`);
                                    return;
                                }
                                if (surface.enabled !== undefined && typeof surface.enabled !== "boolean") {
                                    Plugins.markFailed(slot.modelData.id, `manifest surfaces.${name}.enabled must be a boolean`);
                                    return;
                                }
                                effectiveSurfaces[name] = {
                                    entrypoint: surface.entrypoint,
                                    enabled: surface.enabled !== false
                                };
                                if (name === "dashboard") {
                                    if (surface.size !== undefined)
                                        effectiveSurfaces[name].size = surface.size;
                                    if (surface.category !== undefined)
                                        effectiveSurfaces[name].category = surface.category;
                                }
                            }
                        }
                        // Plugin translations (shell#375): optional in
                        // every schema version. Strict runtime gate
                        // mirroring scripts/validate_plugin.py — a
                        // malformed declaration fails the plugin with
                        // an actionable message instead of silently
                        // loading untranslated. Catalogs themselves are
                        // read by PluginKit Translations; a catalog
                        // that fails to load there degrades to source
                        // strings and never fails the plugin.
                        if (manifest.translations !== undefined) {
                            const translations = manifest.translations;
                            const localeTag = /^[a-z]{2,3}(_[A-Z]{2})?$/;
                            if (!translations || typeof translations !== "object" || Array.isArray(translations)) {
                                Plugins.markFailed(slot.modelData.id, "manifest translations must be an object");
                                return;
                            }
                            const extraTranslations = Object.keys(translations).filter(key => key !== "sourceLocale" && key !== "locales" && key !== "directory");
                            if (extraTranslations.length > 0) {
                                Plugins.markFailed(slot.modelData.id, `manifest translations contains unknown fields: ${extraTranslations.join(", ")}`);
                                return;
                            }
                            if (typeof translations.sourceLocale !== "string" || !localeTag.test(translations.sourceLocale)) {
                                Plugins.markFailed(slot.modelData.id, "manifest translations.sourceLocale must be a locale tag like \"en\" or \"es_AR\"");
                                return;
                            }
                            if (!Array.isArray(translations.locales) || translations.locales.length === 0
                                    || translations.locales.some(l => typeof l !== "string" || !localeTag.test(l))
                                    || new Set(translations.locales).size !== translations.locales.length) {
                                Plugins.markFailed(slot.modelData.id, "manifest translations.locales must be a non-empty list of unique locale tags like \"es\" or \"es_AR\"");
                                return;
                            }
                            const translationsDir = translations.directory === undefined ? "translations" : translations.directory;
                            if (typeof translationsDir !== "string" || translationsDir.includes("..") || translationsDir.includes("\\")
                                    || !/^(?!\/)(?!\.{1,2}(\/|$))(?!.*\/\.{1,2}(\/|$))(?!.*\/\/)[A-Za-z0-9._\/-]+$/.test(translationsDir)
                                    || translationsDir.endsWith("/")) {
                                Plugins.markFailed(slot.modelData.id, "manifest translations.directory is not a safe relative path");
                                return;
                            }
                            for (const locale of translations.locales) {
                                if (!manifest.files.includes(`${translationsDir}/${locale}.json`)) {
                                    Plugins.markFailed(slot.modelData.id, `manifest translations declares locale "${locale}" but files does not list ${translationsDir}/${locale}.json`);
                                    return;
                                }
                            }
                        }
                        // Marketplace metadata (shell#379): optional
                        // in every schema version. Strict runtime
                        // gate mirroring scripts/validate_plugin.py
                        // for enabled packages — screenshots must be
                        // static image files listed in files (never
                        // QML/SVG, so a preview never executes code),
                        // compatibility bounds are ordered semver,
                        // changelog versions are unique semver, and
                        // replacedBy never names the plugin itself.
                        if (manifest.marketplace !== undefined) {
                            const marketplace = manifest.marketplace;
                            const semverRe = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$/;
                            const semverKey = value => {
                                const core = value.split("+")[0];
                                const parts = core.split("-");
                                const numbers = parts[0].split(".").map(n => parseInt(n, 10));
                                return parts.length > 1 ? numbers.concat([0], parts.slice(1).join("-").split(".").map(p => isNaN(parseInt(p, 10)) ? p : parseInt(p, 10))) : numbers.concat([1]);
                            };
                            const semverGreater = (a, b) => {
                                const ka = semverKey(a);
                                const kb = semverKey(b);
                                for (let i = 0; i < Math.max(ka.length, kb.length); i++) {
                                    const va = ka[i] === undefined ? 0 : ka[i];
                                    const vb = kb[i] === undefined ? 0 : kb[i];
                                    if (va === vb)
                                        continue;
                                    if (typeof va === "number" && typeof vb === "number")
                                        return va > vb;
                                    return typeof va === "string" && typeof vb === "number" ? true : typeof va === "number" ? false : String(va) > String(vb);
                                }
                                return false;
                            };
                            if (!marketplace || typeof marketplace !== "object" || Array.isArray(marketplace)
                                    || Object.keys(marketplace).length === 0) {
                                Plugins.markFailed(slot.modelData.id, "manifest marketplace must be a non-empty object");
                                return;
                            }
                            const extraMarketplace = Object.keys(marketplace).filter(key => key !== "screenshots" && key !== "compatibility" && key !== "changelog" && key !== "deprecation");
                            if (extraMarketplace.length > 0) {
                                Plugins.markFailed(slot.modelData.id, `manifest marketplace contains unknown fields: ${extraMarketplace.join(", ")}`);
                                return;
                            }
                            if (marketplace.screenshots !== undefined) {
                                const shots = marketplace.screenshots;
                                if (!Array.isArray(shots) || shots.length === 0 || shots.length > 6
                                        || new Set(shots.map(s => s && s.path)).size !== shots.length) {
                                    Plugins.markFailed(slot.modelData.id, "manifest marketplace.screenshots must list 1 to 6 unique screenshots");
                                    return;
                                }
                                for (const shot of shots) {
                                    if (!shot || typeof shot !== "object" || Array.isArray(shot)
                                            || Object.keys(shot).some(key => key !== "path" && key !== "alt")
                                            || typeof shot.path !== "string"
                                            || !/^(?!\/)(?!\.{1,2}(\/|$))(?!.*\/\.{1,2}(\/|$))(?!.*\/\/)[A-Za-z0-9._\/-]+\.(?:png|jpg|jpeg|webp)$/i.test(shot.path)) {
                                        Plugins.markFailed(slot.modelData.id, "manifest marketplace.screenshots entries must name a static image path (.png/.jpg/.jpeg/.webp) and optional alt");
                                        return;
                                    }
                                    if (!manifest.files.includes(shot.path)) {
                                        Plugins.markFailed(slot.modelData.id, `manifest marketplace screenshot "${shot.path}" must be listed in files`);
                                        return;
                                    }
                                    if (shot.alt !== undefined && (typeof shot.alt !== "string" || !/\S/.test(shot.alt) || shot.alt.length > 160)) {
                                        Plugins.markFailed(slot.modelData.id, "manifest marketplace screenshot alt must be a non-empty string of at most 160 characters");
                                        return;
                                    }
                                }
                            }
                            if (marketplace.compatibility !== undefined) {
                                const compat = marketplace.compatibility;
                                if (!compat || typeof compat !== "object" || Array.isArray(compat)
                                        || Object.keys(compat).length === 0
                                        || Object.keys(compat).some(key => key !== "minShellVersion" && key !== "maxShellVersion")
                                        || Object.keys(compat).some(key => typeof compat[key] !== "string" || !semverRe.test(compat[key]))) {
                                    Plugins.markFailed(slot.modelData.id, "manifest marketplace.compatibility must declare minShellVersion and/or maxShellVersion as semantic versions");
                                    return;
                                }
                                if (compat.minShellVersion !== undefined && compat.maxShellVersion !== undefined
                                        && semverGreater(compat.minShellVersion, compat.maxShellVersion)) {
                                    Plugins.markFailed(slot.modelData.id, "manifest marketplace.compatibility.minShellVersion must not exceed maxShellVersion");
                                    return;
                                }
                            }
                            if (marketplace.changelog !== undefined) {
                                const log = marketplace.changelog;
                                if (!Array.isArray(log) || log.length === 0 || log.length > 20
                                        || new Set(log.map(e => e && e.version)).size !== log.length
                                        || log.some(e => !e || typeof e !== "object" || Array.isArray(e)
                                            || Object.keys(e).some(key => key !== "version" && key !== "notes")
                                            || typeof e.version !== "string" || !semverRe.test(e.version)
                                            || typeof e.notes !== "string" || !/\S/.test(e.notes) || e.notes.length > 1000)) {
                                    Plugins.markFailed(slot.modelData.id, "manifest marketplace.changelog must list 1 to 20 unique {version, notes} entries with semantic versions");
                                    return;
                                }
                            }
                            if (marketplace.deprecation !== undefined) {
                                const deprecation = marketplace.deprecation;
                                if (!deprecation || typeof deprecation !== "object" || Array.isArray(deprecation)
                                        || Object.keys(deprecation).some(key => key !== "message" && key !== "replacedBy")
                                        || (deprecation.message !== undefined && (typeof deprecation.message !== "string" || !/\S/.test(deprecation.message) || deprecation.message.length > 280))
                                        || (deprecation.replacedBy !== undefined && (typeof deprecation.replacedBy !== "string" || !/^[a-z0-9][a-z0-9-]{0,47}$/.test(deprecation.replacedBy) || deprecation.replacedBy === slot.modelData.id))) {
                                    Plugins.markFailed(slot.modelData.id, "manifest marketplace.deprecation must name only an optional message and a replacedBy plugin id different from this plugin");
                                    return;
                                }
                            }
                        }
                        slot.placement = placement;
                        const settings = manifest.capabilities && manifest.capabilities.settings;
                        Plugins.markPlacement(slot.modelData.id, placement, manifest.entrypoint, settings || ({}), effectiveSurfaces);
                        Plugins.markTranslations(slot.modelData.id, manifest.translations === undefined ? null : manifest.translations);
                        Plugins.markMarketplace(slot.modelData.id, manifest.marketplace === undefined ? null : manifest.marketplace);
                        slot.entrypoint = manifest.entrypoint;
                        const background = effectiveSurfaces.background;
                        slot.backgroundEntrypoint = background && background.enabled !== false ? background.entrypoint : "";
                    } catch (e) {
                        Plugins.markFailed(slot.modelData.id, "manifest.json is not readable JSON");
                    }
                }

                onLoadFailed: Plugins.markFailed(slot.modelData.id, "manifest.json could not be read")
            }

            Loader {
                id: pluginLoader

                // Only the effective background surface loads here:
                // visible surfaces are never double-loaded by this
                // headless host, and a background surface added by a
                // v2 manifest loads even when the primary placement
                // is visible. Disabled background surfaces (and v1
                // manifests, which have one only when placement is
                // background) load nothing here.
                active: slot.backgroundEntrypoint !== ""
                source: active ? `file://${slot.pluginDir}/${slot.backgroundEntrypoint}` : ""
                asynchronous: true

                onStatusChanged: {
                    if (status === Loader.Ready)
                        Plugins.markLoaded(slot.modelData.id);
                    else if (status === Loader.Error)
                        Plugins.markFailed(slot.modelData.id, pluginLoader.errorString || "entrypoint failed to load (see shell log)");
                }
            }
        }
    }

    // Marketplace previews for installed-but-disabled packages
    // (shell#379): the delegate above only visits enabled plugins,
    // but a preview must never require enabling (executing) plugin
    // code first. This reader loads ONLY manifest.json as text —
    // there is deliberately no Loader here — and records the
    // normalized marketplace declaration for the Extensions pane.
    // A malformed declaration degrades to no preview; it never
    // fails a disabled plugin that is not being loaded.
    Repeater {
        model: Plugins.entries.filter(e => e.installed && !e.enabled)

        delegate: Item {
            id: previewSlot

            required property var modelData

            FileView {
                id: previewManifestView

                path: `${Plugins.pluginsDir}/${previewSlot.modelData.id}/manifest.json`
                printErrors: false

                onLoaded: {
                    try {
                        const manifest = JSON.parse(previewManifestView.text());
                        if (manifest.id === previewSlot.modelData.id)
                            Plugins.markMarketplace(previewSlot.modelData.id, manifest.marketplace === undefined ? null : manifest.marketplace);
                    } catch (e) {
                        // Unreadable manifest: no preview, no failure.
                    }
                }
            }
        }
    }
    }

    IpcHandler {
        target: "plugins"

        function status(): string {
            return JSON.stringify(Plugins.status());
        }

        function reload(): void {
            Plugins.reload();
        }

        function reloadPlugin(id: string): string {
            return Plugins.reloadPlugin(id) ? "reloading" : "not reloadable (unknown, disabled, or safe mode)";
        }
    }
}
