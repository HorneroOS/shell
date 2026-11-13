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

    function markPlacement(id: string, placement: string, entrypoint: string, settings: var, surfaces: var): void {
        const current = root.entries.find(e => e.id === id);
        const normalized = settings && typeof settings === "object" && !Array.isArray(settings) ? settings : ({});
        const normalizedSurfaces = root.normalizeSurfaces(surfaces, placement, entrypoint);
        if (current && current.placement === placement && current.entrypoint === entrypoint
                && JSON.stringify(current.settings || {}) === JSON.stringify(normalized)
                && JSON.stringify(current.surfaces || {}) === JSON.stringify(normalizedSurfaces))
            return;
        const next = root.entries.map(e => e.id === id ? Object.assign({}, e, {
            placement: placement,
            entrypoint: entrypoint,
            surfaces: normalizedSurfaces,
            settings: settings && typeof settings === "object" && !Array.isArray(settings) ? settings : ({})
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
